"""Refunds, only ever after a moderator or admin ruling.

A UPI refund goes through Razorpay with reverse_all, which pulls the money back
from the owner's linked account (with Route off, it comes from UniRent's own).
A cash refund is recorded at once and completed when the owner marks it handed
back. Either way the ledger gets reversing entries and both sides hear about it."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import audit
from unirent_security.errors import ApiError

from unirent_payments import db, ledger, outbox
from unirent_payments.config import get_settings
from unirent_payments.metrics import PAYMENTS
from unirent_payments.models import Payment, Refund
from unirent_payments.payments import event_payload, get_payment, transition
from unirent_payments.razorpay_client import razorpay


def _now() -> datetime:
    return datetime.now(UTC)


def _apply(session: AsyncSession, payment: Payment, refund: Refund) -> None:
    """Book a completed refund: ledger, payment state, event."""
    payment.refunded_paise += refund.amount_paise
    full = payment.refunded_paise >= payment.amount_paise
    transition(payment, "refunded" if full else "partly_refunded")
    ledger.record_refund(session, payment, refund.id, refund.amount_paise)
    outbox.emit(
        session,
        "RefundIssued",
        payment.booking_ref,
        {
            **event_payload(payment),
            "amount_paise": refund.amount_paise,
            "refund_id": str(refund.id),
            "ruling_ref": str(refund.ruling_ref) if refund.ruling_ref else None,
        },
    )
    PAYMENTS.labels(method=payment.method, outcome="refunded").inc()


async def issue_refund(
    payment_id: uuid.UUID,
    amount_paise: int,
    ruling_ref: uuid.UUID | None,
    by: uuid.UUID | None = None,
) -> Refund:
    async with db.sessionmaker()() as session:
        payment = await get_payment(session, payment_id, lock=True)
        if payment.status not in ("captured", "marked_paid", "partly_refunded"):
            raise ApiError(409, "NOT_REFUNDABLE", "Only paid payments can be refunded")
        pending = await session.scalar(
            select(Refund.id).where(
                Refund.payment_id == payment.id, Refund.status.in_(("pending", "cash_pending"))
            )
        )
        if pending is not None:
            raise ApiError(409, "REFUND_PENDING", "A refund for this payment is still pending")
        if amount_paise <= 0 or amount_paise > payment.amount_paise - payment.refunded_paise:
            raise ApiError(422, "INVALID_REFUND", "The refund is more than what's left to refund")
        refund = Refund(
            id=uuid.uuid4(),
            payment_id=payment.id,
            amount_paise=amount_paise,
            ruling_ref=ruling_ref,
            method=payment.method,
            status="cash_pending" if payment.method == "cash" else "pending",
            created_at=_now(),
        )
        session.add(refund)
        if payment.method == "upi":
            body = {
                "amount": amount_paise,
                "notes": {"refund": str(refund.id), "ruling": str(ruling_ref or "")},
            }
            if get_settings().razorpay_route:
                body["reverse_all"] = 1
            result = await razorpay().refund(
                payment.razorpay_payment_id,  # type: ignore[arg-type]
                body,
            )
            refund.razorpay_refund_id = result["id"]
            if result.get("status") == "processed":
                refund.status = "processed"
                refund.processed_at = _now()
                _apply(session, payment, refund)
        await audit.record(
            by,
            "payment.refund_issued",
            audit.target("payment", payment.id),
            {"amount_paise": amount_paise, "ruling": str(ruling_ref) if ruling_ref else None},
            session=session,
        )
        await session.commit()
        return refund


async def refund_processed(session: AsyncSession, razorpay_refund_id: str) -> bool:
    """Razorpay's refund.processed webhook, for refunds that were still pending."""
    refund = await session.scalar(
        select(Refund).where(Refund.razorpay_refund_id == razorpay_refund_id).with_for_update()
    )
    if refund is None or refund.status != "pending":
        return False
    payment = await get_payment(session, refund.payment_id, lock=True)
    refund.status = "processed"
    refund.processed_at = _now()
    _apply(session, payment, refund)
    return True


async def mark_cash_refunded(refund_id: uuid.UUID, by: uuid.UUID) -> Refund:
    """The owner confirms they handed the cash back."""
    async with db.sessionmaker()() as session:
        refund = await session.get(Refund, refund_id, with_for_update=True)
        if refund is None:
            raise ApiError(404, "NOT_FOUND", "Refund not found")
        payment = await get_payment(session, refund.payment_id, lock=True)
        if payment.payee_id != by:
            raise ApiError(404, "NOT_FOUND", "Refund not found")
        if refund.status == "cash_done":
            return refund
        if refund.status != "cash_pending":
            raise ApiError(409, "NOT_CASH", "Only cash refunds are marked done")
        refund.status = "cash_done"
        refund.marked_by = by
        refund.processed_at = _now()
        _apply(session, payment, refund)
        await audit.record(
            by, "payment.cash_refunded", audit.target("refund", refund.id), session=session
        )
        await session.commit()
        return refund
