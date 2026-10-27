"""The append-only double-entry ledger.

Each student has a ledger account per role in the money flow, named
`student:<id>`. A payment debits the payer and credits the payee; a refund
does the reverse. There is no platform account: UniRent holds no money and
takes no fee."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_payments.models import LedgerEntry, Payment


def account_name(account_id: uuid.UUID) -> str:
    return f"student:{account_id}"


def _post(
    session: AsyncSession,
    *,
    kind: str,
    debit: str,
    credit: str,
    amount_paise: int,
    payment: Payment,
    refund_id: uuid.UUID | None = None,
    memo: str | None = None,
) -> uuid.UUID:
    if amount_paise <= 0:
        raise ValueError("ledger amounts are positive")
    txn = uuid.uuid4()
    now = datetime.now(UTC)
    for ledger_account, direction in ((debit, "debit"), (credit, "credit")):
        session.add(
            LedgerEntry(
                txn_id=txn,
                kind=kind,
                ledger_account=ledger_account,
                direction=direction,
                amount_paise=amount_paise,
                payment_id=payment.id,
                refund_id=refund_id,
                booking_ref=payment.booking_ref,
                channel=payment.method,
                memo=memo,
                created_at=now,
            )
        )
    return txn


def record_payment(session: AsyncSession, payment: Payment) -> uuid.UUID:
    """Money moved from payer to payee (captured UPI or cash marked paid)."""
    return _post(
        session,
        kind="payment" if payment.method == "upi" else "cash_payment",
        debit=account_name(payment.payer_id),
        credit=account_name(payment.payee_id),
        amount_paise=payment.amount_paise,
        payment=payment,
        memo=payment.purpose,
    )


def record_refund(
    session: AsyncSession, payment: Payment, refund_id: uuid.UUID, amount_paise: int
) -> uuid.UUID:
    """Money moved back from payee to payer after a ruling."""
    return _post(
        session,
        kind="refund" if payment.method == "upi" else "cash_refund",
        debit=account_name(payment.payee_id),
        credit=account_name(payment.payer_id),
        amount_paise=amount_paise,
        payment=payment,
        refund_id=refund_id,
        memo="refund",
    )


@dataclass(frozen=True)
class TrialBalance:
    debits_paise: int
    credits_paise: int
    unbalanced_txns: int

    @property
    def balanced(self) -> bool:
        return self.debits_paise == self.credits_paise and self.unbalanced_txns == 0


async def trial_balance(session: AsyncSession) -> TrialBalance:
    signed = case((LedgerEntry.direction == "debit", LedgerEntry.amount_paise), else_=0)
    credit = case((LedgerEntry.direction == "credit", LedgerEntry.amount_paise), else_=0)
    debits, credits = (
        await session.execute(
            select(func.coalesce(func.sum(signed), 0), func.coalesce(func.sum(credit), 0))
        )
    ).one()
    per_txn = (
        select(LedgerEntry.txn_id)
        .group_by(LedgerEntry.txn_id)
        .having(func.sum(signed) != func.sum(credit))
        .subquery()
    )
    unbalanced = await session.scalar(select(func.count()).select_from(per_txn))
    return TrialBalance(int(debits), int(credits), int(unbalanced or 0))


async def balance_of(session: AsyncSession, account_id: uuid.UUID) -> int:
    """Net received minus paid for one student, in paise."""
    name = account_name(account_id)
    signed = case(
        (LedgerEntry.direction == "credit", LedgerEntry.amount_paise),
        else_=-LedgerEntry.amount_paise,
    )
    total = await session.scalar(
        select(func.coalesce(func.sum(signed), 0)).where(LedgerEntry.ledger_account == name)
    )
    return int(total or 0)


async def entries_for_booking(session: AsyncSession, booking_ref: uuid.UUID) -> list[LedgerEntry]:
    rows = await session.scalars(
        select(LedgerEntry).where(LedgerEntry.booking_ref == booking_ref).order_by(LedgerEntry.id)
    )
    return list(rows)
