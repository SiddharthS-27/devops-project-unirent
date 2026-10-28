import uuid

import pytest
import unirent_security.db
from unirent_security.errors import ApiError

from unirent_payments import db
from unirent_payments.payments import mark_cash_paid, payment_status, start_payment


@pytest.fixture(autouse=True)
async def _reset(session):
    yield
    await db.reset()
    await unirent_security.db.reset()


ITEMS = [
    {"label": "Late fee", "amount_paise": 1300},
    {"label": "Damage charge", "amount_paise": 20000},
    {"label": "Extension paid in cash", "amount_paise": 5000},
]


async def test_return_charges_are_itemised_and_must_add_up(session):
    booking, payer, payee = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    with pytest.raises(ApiError):
        await start_payment(booking, "return_charges", payer, payee, 26300, "cash", "k0")
    with pytest.raises(ApiError):
        await start_payment(booking, "return_charges", payer, payee, 1, "cash", "k1", items=ITEMS)
    p = await start_payment(
        booking, "return_charges", payer, payee, 26300, "cash", "k2", items=ITEMS
    )
    assert [i["label"] for i in p.items] == [i["label"] for i in ITEMS]


async def test_each_extension_is_paid_separately(session):
    booking, payer, payee = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    with pytest.raises(ApiError):
        await start_payment(booking, "extension", payer, payee, 5000, "cash", "k0")
    first, second = uuid.uuid4(), uuid.uuid4()
    a = await start_payment(
        booking, "extension", payer, payee, 5000, "cash", "k1", purpose_ref=first
    )
    await mark_cash_paid(a.id, payee)
    b = await start_payment(
        booking, "extension", payer, payee, 3000, "cash", "k2", purpose_ref=second
    )
    assert b.id != a.id
    assert (await payment_status(booking, "extension", first)).is_paid
    assert not (await payment_status(booking, "extension", second)).is_paid
