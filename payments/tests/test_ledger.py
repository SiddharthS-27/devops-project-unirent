import uuid
from datetime import UTC, datetime

import pytest
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError

from unirent_payments import ledger
from unirent_payments.models import Payment


def _payment(amount=5000, method="upi") -> Payment:
    now = datetime.now(UTC)
    return Payment(
        id=uuid.uuid4(),
        booking_ref=uuid.uuid4(),
        purpose="rent",
        payer_id=uuid.uuid4(),
        payee_id=uuid.uuid4(),
        amount_paise=amount,
        method=method,
        status="captured",
        idempotency_key=uuid.uuid4().hex,
        created_at=now,
        updated_at=now,
    )


async def test_payment_and_refund_balance(session):
    payment = _payment(5000)
    ledger.record_payment(session, payment)
    ledger.record_refund(session, payment, uuid.uuid4(), 2000)
    await session.commit()

    assert await ledger.balance_of(session, payment.payee_id) == 3000
    assert await ledger.balance_of(session, payment.payer_id) == -3000
    entries = await ledger.entries_for_booking(session, payment.booking_ref)
    assert [e.direction for e in entries] == ["debit", "credit", "debit", "credit"]
    assert (await ledger.trial_balance(session)).balanced


async def test_ledger_is_append_only(session):
    payment = _payment()
    ledger.record_payment(session, payment)
    await session.commit()
    for statement in (
        "UPDATE payments.ledger_entries SET amount_paise = 1",
        "DELETE FROM payments.ledger_entries",
    ):
        with pytest.raises(DBAPIError):
            await session.execute(text(statement))
        await session.rollback()


def test_amounts_must_be_positive():
    class S:
        def add(self, _):
            pass

    with pytest.raises(ValueError):
        ledger.record_refund(S(), _payment(), uuid.uuid4(), 0)
