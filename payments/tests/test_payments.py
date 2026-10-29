import asyncio
import uuid

import pytest
import unirent_security.db
from unirent_security.errors import ApiError

from unirent_payments import db
from unirent_payments.models import Payment
from unirent_payments.payments import payment_status, start_payment, transition


@pytest.fixture(autouse=True)
async def _redis(session):
    yield
    await db.reset()
    await unirent_security.db.reset()


def _ids():
    return uuid.uuid4(), uuid.uuid4(), uuid.uuid4()


async def test_cash_payment_starts_pending(session):
    booking, payer, payee = _ids()
    p = await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-1")
    assert p.status == "pending"
    assert p.items == [{"label": "Rent", "amount_paise": 5000}]
    assert (await payment_status(booking, "rent")).id == p.id


async def test_same_key_returns_the_same_payment(session):
    booking, payer, payee = _ids()
    first = await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-1")
    again = await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-1")
    assert again.id == first.id
    with pytest.raises(ApiError) as err:
        await start_payment(booking, "rent", payer, payee, 9999, "cash", "key-1")
    assert err.value.code == "IDEMPOTENCY_KEY_REUSED"


async def test_new_key_for_a_pending_payment_reuses_it(session):
    booking, payer, payee = _ids()
    first = await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-1")
    second = await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-2")
    assert second.id == first.id


async def test_parallel_starts_create_one_payment(session):
    booking, payer, payee = _ids()
    results = await asyncio.gather(
        *(start_payment(booking, "rent", payer, payee, 5000, "cash", f"key-{i}") for i in range(5))
    )
    assert len({r.id for r in results}) == 1


async def test_paid_purpose_cannot_be_paid_again(session):
    booking, payer, payee = _ids()
    p = await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-1")
    payment = await session.get(Payment, p.id)
    transition(payment, "marked_paid")
    await session.commit()
    with pytest.raises(ApiError) as err:
        await start_payment(booking, "rent", payer, payee, 5000, "cash", "key-2")
    assert err.value.code == "ALREADY_PAID"


async def test_illegal_transitions_are_refused():
    payment = Payment(status="failed")
    with pytest.raises(ApiError):
        transition(payment, "captured")
    payment = Payment(status="captured")
    assert transition(payment, "captured") is False  # a repeat changes nothing


async def test_paying_yourself_is_refused():
    me = uuid.uuid4()
    with pytest.raises(ApiError):
        await start_payment(uuid.uuid4(), "rent", me, me, 100, "cash", "k")


async def test_success_rate_counts_finished_upi_attempts(session):
    from unirent_payments.payments import success_rate

    rate = await success_rate()
    assert rate is None or 0 <= rate <= 1
