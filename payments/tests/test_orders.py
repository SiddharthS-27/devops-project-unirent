import uuid

import pytest
import unirent_security.db
from unirent_security.errors import ApiError

from tests.fake_razorpay import FakeRazorpay
from tests.helpers import ready_payee
from unirent_payments import db
from unirent_payments.payments import start_payment
from unirent_payments.razorpay_client import RazorpayClient, use_client


@pytest.fixture
async def fake(session):
    fake = FakeRazorpay()
    use_client(RazorpayClient(transport=fake.transport()))
    yield fake
    use_client(None)
    await db.reset()
    await unirent_security.db.reset()


async def test_upi_creates_an_order_that_transfers_everything_to_the_payee(fake):
    payee, linked = await ready_payee()
    booking, payer = uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 30000, "upi", "k1")
    assert p.status == "pending"
    order = fake.orders[p.checkout["order_id"]]
    assert order["amount"] == 30000
    assert order["transfers"] == [
        {
            "account": linked,
            "amount": 30000,
            "currency": "INR",
            "notes": {"payment": str(p.id)},
            "on_hold": False,
        }
    ]
    assert p.checkout["key_id"] and p.checkout["amount_paise"] == 30000


async def test_payee_without_a_ready_account_cannot_take_upi(fake):
    payee, _ = await ready_payee("under_review")
    with pytest.raises(ApiError) as err:
        await start_payment(uuid.uuid4(), "rent", uuid.uuid4(), payee, 100, "upi", "k1")
    assert err.value.code == "PAYEE_NOT_PAYOUT_READY"


async def test_switching_to_cash_after_paying_by_upi_is_refused(fake):
    payee, _ = await ready_payee()
    booking, payer = uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 5000, "upi", "k1")
    fake.pay(p.checkout["order_id"])
    with pytest.raises(ApiError) as err:
        await start_payment(booking, "rent", payer, payee, 5000, "cash", "k2")
    assert err.value.code == "PAYMENT_ALREADY_MADE"


async def test_switching_to_cash_before_paying_replaces_the_attempt(fake):
    payee, _ = await ready_payee()
    booking, payer = uuid.uuid4(), uuid.uuid4()
    upi = await start_payment(booking, "rent", payer, payee, 5000, "upi", "k1")
    cash = await start_payment(booking, "rent", payer, payee, 5000, "cash", "k2")
    assert cash.id != upi.id and cash.status == "pending"
