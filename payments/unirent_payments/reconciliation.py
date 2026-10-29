"""Reconciliation: does the ledger agree with Razorpay for a day?

For every UPI payment we captured that day, Razorpay must have the payment,
captured, for the same amount, with a processed transfer of that amount to the
owner's linked account. Every payment Razorpay captured must be one we know. Our
refunds must match Razorpay's. Test mode makes no settlements, so settlement
records are counted when present and never flagged when absent."""

import uuid
from collections.abc import Iterable
from datetime import UTC, date, datetime, time, timedelta, timezone
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_payments import db, outbox
from unirent_payments.metrics import RECONCILIATION_MISMATCHES
from unirent_payments.models import (
    LedgerEntry,
    Payment,
    ReconciliationMismatch,
    ReconciliationRun,
    Refund,
)
from unirent_payments.razorpay_client import razorpay

IST = timezone(timedelta(hours=5, minutes=30))
PAID_UPI = ("captured", "refunded", "partly_refunded")


def day_window(day: date) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time.min, tzinfo=IST)
    return start, start + timedelta(days=1)


def yesterday_ist() -> date:
    return (datetime.now(IST) - timedelta(days=1)).date()


class Report:
    def __init__(self) -> None:
        self.mismatches: list[dict[str, Any]] = []

    def add(self, kind: str, reference: str, **values: Any) -> None:
        self.mismatches.append({"kind": kind, "reference": reference, **values})


async def _ledger_amount(session: AsyncSession, payment_id: uuid.UUID) -> int:
    """What the ledger says moved for a payment: credits to the payee net of refunds."""
    total = await session.scalar(
        select(func.coalesce(func.sum(LedgerEntry.amount_paise), 0)).where(
            LedgerEntry.payment_id == payment_id,
            LedgerEntry.direction == "credit",
            LedgerEntry.kind == "payment",
        )
    )
    return int(total or 0)


async def compare(
    session: AsyncSession,
    ours: Iterable[Payment],
    theirs: dict[str, dict[str, Any]],
    our_refunds: Iterable[Refund],
    their_refunds: dict[str, dict[str, Any]],
) -> Report:
    report = Report()
    ours = list(ours)
    known = {p.razorpay_payment_id for p in ours if p.razorpay_payment_id}
    for payment in ours:
        ref = payment.razorpay_payment_id or str(payment.id)
        rp = theirs.get(payment.razorpay_payment_id or "")
        ledger_amount = await _ledger_amount(session, payment.id)
        if ledger_amount != payment.amount_paise:
            report.add(
                "ledger_incomplete",
                ref,
                payment_id=payment.id,
                ledger_amount_paise=ledger_amount,
                razorpay_amount_paise=payment.amount_paise,
            )
        if rp is None:
            rp = await _fetch(payment.razorpay_payment_id)
        if rp is None:
            report.add(
                "missing_in_razorpay",
                ref,
                payment_id=payment.id,
                ledger_amount_paise=payment.amount_paise,
                ledger_status=payment.status,
            )
            continue
        if rp["amount"] != payment.amount_paise:
            report.add(
                "amount_differs",
                ref,
                payment_id=payment.id,
                ledger_amount_paise=payment.amount_paise,
                razorpay_amount_paise=rp["amount"],
            )
        if rp["status"] not in ("captured", "refunded"):
            report.add(
                "status_differs",
                ref,
                payment_id=payment.id,
                ledger_status=payment.status,
                razorpay_status=rp["status"],
            )
        transfers = await razorpay().payment_transfers(rp["id"])
        transferred = sum(
            t["amount"] for t in transfers if t.get("status", "processed") == "processed"
        )
        if transferred != payment.amount_paise:
            report.add(
                "transfer_missing",
                ref,
                payment_id=payment.id,
                ledger_amount_paise=payment.amount_paise,
                razorpay_amount_paise=transferred,
            )
    for payment_id, rp in theirs.items():
        if rp.get("status") in ("captured", "refunded") and payment_id not in known:
            ledger_known = await session.scalar(
                select(Payment.id).where(Payment.razorpay_payment_id == payment_id)
            )
            if ledger_known is None:
                report.add(
                    "missing_in_ledger",
                    payment_id,
                    razorpay_amount_paise=rp["amount"],
                    razorpay_status=rp["status"],
                )
    our_refund_ids = {r.razorpay_refund_id: r for r in our_refunds if r.razorpay_refund_id}
    for refund_id, refund in our_refund_ids.items():
        rp_refund = their_refunds.get(refund_id)
        if rp_refund is None or rp_refund["amount"] != refund.amount_paise:
            report.add(
                "refund_differs",
                refund_id,
                payment_id=refund.payment_id,
                ledger_amount_paise=refund.amount_paise,
                razorpay_amount_paise=rp_refund["amount"] if rp_refund else None,
            )
    return report


async def _fetch(payment_id: str | None) -> dict[str, Any] | None:
    if not payment_id:
        return None
    try:
        return await razorpay().fetch_payment(payment_id)
    except Exception:  # noqa: BLE001 - absent counts as a mismatch, not a crash
        return None


async def run(day: date | None = None, triggered_by: str = "nightly") -> ReconciliationRun:
    day = day or yesterday_ist()
    start, end = day_window(day)
    async with db.sessionmaker()() as session:
        record = ReconciliationRun(
            id=uuid.uuid4(),
            day=day,
            triggered_by=triggered_by,
            status="running",
            totals={},
            started_at=datetime.now(UTC),
        )
        session.add(record)
        await session.commit()
        try:
            ours = list(
                await session.scalars(
                    select(Payment).where(
                        Payment.method == "upi",
                        Payment.status.in_(PAID_UPI),
                        Payment.paid_at >= start,
                        Payment.paid_at < end,
                    )
                )
            )
            our_refunds = list(
                await session.scalars(
                    select(Refund).where(
                        Refund.method == "upi", Refund.created_at >= start, Refund.created_at < end
                    )
                )
            )
            client = razorpay()
            window = (int(start.timestamp()), int(end.timestamp()))
            theirs = {p["id"]: p for p in await client.payments_between(*window)}
            their_refunds = {r["id"]: r for r in await client.refunds_between(*window)}
            settlements = await client.settlements_between(*window)
            report = await compare(session, ours, theirs, our_refunds, their_refunds)
            for item in report.mismatches:
                session.add(ReconciliationMismatch(run_id=record.id, **item))
                outbox.emit(
                    session,
                    "ReconciliationMismatchFound",
                    record.id,
                    {
                        "run_id": str(record.id),
                        "kind": item["kind"],
                        "reference": item["reference"],
                        "ledger_amount_paise": item.get("ledger_amount_paise"),
                        "razorpay_amount_paise": item.get("razorpay_amount_paise"),
                    },
                )
            record.totals = {
                "payments_checked": len(ours),
                "razorpay_payments": len(theirs),
                "refunds_checked": len(our_refunds),
                "settlements": len(settlements),
                "settlements_available": bool(settlements),
                "mismatches": len(report.mismatches),
            }
            record.status = "done"
            RECONCILIATION_MISMATCHES.set(len(report.mismatches))
        except Exception as exc:
            record.status = "failed"
            record.error = str(exc)[:1000]
            raise
        finally:
            record.finished_at = datetime.now(UTC)
            await session.commit()
        return record


async def mismatches(session: AsyncSession, run_id: uuid.UUID) -> list[ReconciliationMismatch]:
    rows = await session.scalars(
        select(ReconciliationMismatch)
        .where(ReconciliationMismatch.run_id == run_id)
        .order_by(ReconciliationMismatch.id)
    )
    return list(rows)
