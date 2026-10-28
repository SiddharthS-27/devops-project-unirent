"""Payments: the state machine and the functions the backend calls.

created -> pending      order created, or cash chosen
pending -> captured     verified checkout or captured webhook
pending -> failed       failed webhook, or replaced by a new attempt
pending -> marked_paid  the payee marks cash received
captured | marked_paid -> refunded | partly_refunded
"""

import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import audit, rate_limit_hit
from unirent_security.errors import ApiError

from unirent_payments import db, ledger, orders, outbox
from unirent_payments.metrics import PAYMENTS
from unirent_payments.models import LIVE_STATUSES, PAID_STATUSES, Payment

log = logging.getLogger(__name__)

PURPOSES = ("rent", "extension", "return_charges", "sale")
METHODS = ("upi", "cash")

TRANSITIONS: dict[str, set[str]] = {
    "created": {"pending", "failed"},
    "pending": {"captured", "failed", "marked_paid"},
    "captured": {"refunded", "partly_refunded"},
    "marked_paid": {"refunded", "partly_refunded"},
    "partly_refunded": {"refunded", "partly_refunded"},
    "refunded": set(),
    "failed": set(),
}


def _now() -> datetime:
    return datetime.now(UTC)


@dataclass(frozen=True)
class PaymentView:
    """What the backend gets back; it renders it into its own response models."""

    id: uuid.UUID
    booking_ref: uuid.UUID
    purpose: str
    purpose_ref: uuid.UUID | None
    payer_id: uuid.UUID
    payee_id: uuid.UUID
    method: str
    status: str
    amount_paise: int
    items: list[dict[str, Any]]
    created_at: datetime
    paid_at: datetime | None
    refunded_paise: int
    checkout: dict[str, Any] | None = field(default=None)

    @property
    def is_paid(self) -> bool:
        return self.status in PAID_STATUSES


def _label(purpose: str) -> str:
    return {
        "rent": "Rent",
        "extension": "Extension",
        "return_charges": "Return charges",
        "sale": "Sale price",
    }[purpose]


def view(payment: Payment, checkout: dict[str, Any] | None = None) -> PaymentView:
    return PaymentView(
        id=payment.id,
        booking_ref=payment.booking_ref,
        purpose=payment.purpose,
        purpose_ref=payment.purpose_ref,
        payer_id=payment.payer_id,
        payee_id=payment.payee_id,
        method=payment.method,
        status=payment.status,
        amount_paise=payment.amount_paise,
        items=payment.items or [],
        created_at=payment.created_at,
        paid_at=payment.paid_at,
        refunded_paise=payment.refunded_paise,
        checkout=checkout,
    )


def transition(payment: Payment, to: str, reason: str | None = None) -> bool:
    """Move a payment; returns False when it is already in `to` (a repeat)."""
    if payment.status == to and to not in ("partly_refunded",):
        return False
    if to not in TRANSITIONS[payment.status]:
        raise ApiError(
            409, "PAYMENT_STATE_CONFLICT", f"A {payment.status} payment can't become {to}"
        )
    payment.status = to
    payment.updated_at = _now()
    if reason:
        payment.failure_reason = reason
    if to in ("captured", "marked_paid"):
        payment.paid_at = _now()
    return True


async def _live_payment(
    session: AsyncSession, booking_ref: uuid.UUID, purpose: str, purpose_ref: uuid.UUID | None
) -> Payment | None:
    stmt = (
        select(Payment)
        .where(
            Payment.booking_ref == booking_ref,
            Payment.purpose == purpose,
            Payment.status.in_(LIVE_STATUSES),
        )
        .with_for_update()
    )
    stmt = stmt.where(
        Payment.purpose_ref == purpose_ref if purpose_ref else Payment.purpose_ref.is_(None)
    )
    return await session.scalar(stmt)


async def _begin_upi(session: AsyncSession, payment: Payment) -> dict[str, Any] | None:
    await orders.create_order(session, payment)
    transition(payment, "pending")
    return orders.checkout(payment)


async def checkout_for(payment: Payment) -> dict[str, Any] | None:
    return orders.checkout(payment)


async def start_payment(
    booking_ref: uuid.UUID,
    purpose: str,
    payer: uuid.UUID,
    payee: uuid.UUID,
    amount_paise: int,
    method: str,
    idempotency_key: str,
    *,
    items: list[dict[str, Any]] | None = None,
    purpose_ref: uuid.UUID | None = None,
) -> PaymentView:
    """Start paying for something, at most once.

    The same idempotency key returns the same payment. A second key for something
    already paid is refused; for something still pending it returns the pending
    payment, or replaces it when the payer switches method."""
    if purpose not in PURPOSES or method not in METHODS:
        raise ApiError(422, "INVALID_PAYMENT", "Unknown payment purpose or method")
    if amount_paise <= 0:
        raise ApiError(422, "INVALID_AMOUNT", "Nothing to pay")
    if payer == payee:
        raise ApiError(422, "INVALID_PAYMENT", "You can't pay yourself")

    async with db.sessionmaker()() as session:
        existing = await session.scalar(
            select(Payment).where(
                Payment.payer_id == payer, Payment.idempotency_key == idempotency_key
            )
        )
        if existing is not None:
            same = (
                existing.booking_ref == booking_ref
                and existing.purpose == purpose
                and existing.amount_paise == amount_paise
                and existing.method == method
            )
            if not same:
                raise ApiError(
                    422, "IDEMPOTENCY_KEY_REUSED", "This key was used for a different payment"
                )
            return view(existing, await checkout_for(existing))

        await rate_limit_hit("payment_start", f"acct:{payer}")

        live = await _live_payment(session, booking_ref, purpose, purpose_ref)
        if live is not None:
            if live.status in PAID_STATUSES:
                raise ApiError(409, "ALREADY_PAID", "This has already been paid")
            if live.method == method and live.amount_paise == amount_paise:
                return view(live, await checkout_for(live))
            await supersede(session, live)

        now = _now()
        payment = Payment(
            id=uuid.uuid4(),
            booking_ref=booking_ref,
            purpose=purpose,
            purpose_ref=purpose_ref,
            payer_id=payer,
            payee_id=payee,
            amount_paise=amount_paise,
            items=items
            or [{"label": purpose.replace("_", " ").title(), "amount_paise": amount_paise}],
            method=method,
            status="created",
            idempotency_key=idempotency_key,
            created_at=now,
            updated_at=now,
        )
        session.add(payment)
        try:
            await session.flush()
        except IntegrityError:
            # A parallel request for the same thing won; hand back its payment.
            await session.rollback()
            winner = await _live_payment(session, booking_ref, purpose, purpose_ref)
            if winner is None:
                raise
            return view(winner, await checkout_for(winner))

        checkout = None
        if method == "cash":
            transition(payment, "pending")
        else:
            checkout = await _begin_upi(session, payment)
        await session.commit()
        return view(payment, checkout)


async def supersede(session: AsyncSession, payment: Payment) -> None:
    """Close an unpaid attempt so a new one can start (the payer switched method).
    A UPI attempt the payer already completed in Checkout is not closed: that
    money moved, so the new attempt is refused instead."""
    if payment.method == "upi" and await orders.captured_on_razorpay(payment):
        await session.commit()
        raise ApiError(
            409, "PAYMENT_ALREADY_MADE", "Your UPI payment went through; refresh to see it"
        )
    transition(payment, "failed", reason="superseded")
    await session.flush()


async def payment_status(
    booking_ref: uuid.UUID, purpose: str, purpose_ref: uuid.UUID | None = None
) -> PaymentView | None:
    """The live payment for this booking and purpose, if any."""
    async with db.sessionmaker()() as session:
        payment = await _live_payment(session, booking_ref, purpose, purpose_ref)
        return view(payment, await checkout_for(payment)) if payment else None


async def payments_for_booking(booking_ref: uuid.UUID) -> list[PaymentView]:
    async with db.sessionmaker()() as session:
        rows = await session.scalars(
            select(Payment).where(Payment.booking_ref == booking_ref).order_by(Payment.created_at)
        )
        return [view(p) for p in rows]


def event_payload(payment: Payment) -> dict[str, Any]:
    return {
        "payment_id": str(payment.id),
        "booking_id": str(payment.booking_ref),
        "purpose": payment.purpose,
        "purpose_ref": str(payment.purpose_ref) if payment.purpose_ref else None,
        "payer_id": str(payment.payer_id),
        "payee_id": str(payment.payee_id),
        "amount_paise": payment.amount_paise,
        "method": payment.method,
    }


async def capture(session: AsyncSession, payment: Payment, razorpay_payment_id: str) -> bool:
    """Record a UPI payment as captured. Verify and webhook both call this, in
    either order; the second call finds it captured and does nothing."""
    if payment.status in PAID_STATUSES:
        return False
    if payment.status == "failed":
        # A later attempt in the same Checkout succeeded after one failed.
        live = await _live_payment(
            session, payment.booking_ref, payment.purpose, payment.purpose_ref
        )
        if live is not None and live.id != payment.id:
            payment.failure_reason = f"captured late as {razorpay_payment_id}; needs a refund"
            log.warning("late capture on a replaced payment", extra={"payment": str(payment.id)})
            return False
        payment.status = "pending"
    transition(payment, "captured")
    payment.razorpay_payment_id = razorpay_payment_id
    ledger.record_payment(session, payment)
    outbox.emit(session, "PaymentCaptured", payment.booking_ref, event_payload(payment))
    PAYMENTS.labels(method="upi", outcome="captured").inc()
    return True


async def fail(session: AsyncSession, payment: Payment, reason: str) -> bool:
    if payment.status != "pending":
        return False
    transition(payment, "failed", reason=reason)
    outbox.emit(session, "PaymentFailed", payment.booking_ref, event_payload(payment))
    PAYMENTS.labels(method=payment.method, outcome="failed").inc()
    return True


async def mark_cash_paid(payment_id: uuid.UUID, by: uuid.UUID) -> PaymentView:
    """The payee confirms cash in hand. Only the payee can; the payer doesn't confirm."""
    async with db.sessionmaker()() as session:
        payment = await get_payment(session, payment_id, lock=True)
        if payment.payee_id != by:
            raise ApiError(404, "NOT_FOUND", "Payment not found")
        if payment.method != "cash":
            raise ApiError(409, "NOT_CASH", "Only cash payments are marked as paid")
        if payment.status == "marked_paid":
            return view(payment)
        transition(payment, "marked_paid")
        payment.marked_by = by
        ledger.record_payment(session, payment)
        outbox.emit(session, "CashMarkedPaid", payment.booking_ref, event_payload(payment))
        await audit.record(
            by, "payment.cash_marked_paid", audit.target("payment", payment.id), session=session
        )
        PAYMENTS.labels(method="cash", outcome="marked_paid").inc()
        await session.commit()
        return view(payment)


async def get_payment(session: AsyncSession, payment_id: uuid.UUID, *, lock: bool = False):
    payment = await session.get(Payment, payment_id, with_for_update=lock)
    if payment is None:
        raise ApiError(404, "NOT_FOUND", "Payment not found")
    return payment
