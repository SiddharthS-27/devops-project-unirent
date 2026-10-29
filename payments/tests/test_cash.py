import uuid

import pytest
import unirent_security.db
from unirent_security.errors import ApiError

from unirent_payments import db, ledger
from unirent_payments.payments import mark_cash_paid, start_payment


@pytest.fixture(autouse=True)
async def _reset(session):
    yield
    await db.reset()
    await unirent_security.db.reset()


async def test_only_the_payee_marks_cash_received(session):
    booking, payer, payee = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 5000, "cash", "k1")
    with pytest.raises(ApiError):
        await mark_cash_paid(p.id, payer)
    marked = await mark_cash_paid(p.id, payee)
    assert marked.status == "marked_paid" and marked.is_paid
    again = await mark_cash_paid(p.id, payee)  # a second tap changes nothing
    assert again.status == "marked_paid"
    entries = await ledger.entries_for_booking(session, booking)
    assert [(e.direction, e.channel) for e in entries] == [("debit", "cash"), ("credit", "cash")]
