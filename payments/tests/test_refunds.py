import uuid

import pytest
from sqlalchemy import select
from unirent_security.errors import ApiError

from tests.test_webhooks import _upi, _verify, env  # noqa: F401 - fixture
from unirent_payments import ledger
from unirent_payments.config import get_settings
from unirent_payments.models import Payment
from unirent_payments.payments import mark_cash_paid, start_payment
from unirent_payments.refunds import issue_refund, mark_cash_refunded

pytestmark = pytest.mark.payments


async def test_upi_refund_reverses_the_transfer(env, session):  # noqa: F811
    fake, client = env
    p, paid, payer = await _upi(fake)
    await _verify(client, p, paid, payer)
    ruling = uuid.uuid4()
    refund = await issue_refund(p.id, 10000, ruling)
    assert refund.status == "processed"
    sent = next(r for r in fake.refunds.values() if r["id"] == refund.razorpay_refund_id)
    assert sent["amount"] == 10000 and sent["reverse_all"] == 1

    payment = await session.get(Payment, p.id)
    await session.refresh(payment)
    assert payment.status == "partly_refunded" and payment.refunded_paise == 10000
    assert await ledger.balance_of(session, payer) == -(30000 - 10000)

    with pytest.raises(ApiError):
        await issue_refund(p.id, 25000, ruling)  # more than what's left
    await issue_refund(p.id, 20000, ruling)
    await session.refresh(payment)
    assert payment.status == "refunded"
    assert (await ledger.trial_balance(session)).balanced


async def test_without_route_upi_refund_reverses_nothing(env, monkeypatch):  # noqa: F811
    monkeypatch.setattr(get_settings(), "razorpay_route", False)
    fake, client = env
    p, paid, payer = await _upi(fake)
    await _verify(client, p, paid, payer)
    refund = await issue_refund(p.id, 10000, uuid.uuid4())
    sent = next(r for r in fake.refunds.values() if r["id"] == refund.razorpay_refund_id)
    assert "reverse_all" not in sent


async def test_cash_refund_waits_for_the_owner(env, session):  # noqa: F811
    booking, payer, payee = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 5000, "cash", "k1")
    await mark_cash_paid(p.id, payee)
    refund = await issue_refund(p.id, 5000, uuid.uuid4())
    assert refund.status == "cash_pending"
    with pytest.raises(ApiError):
        await mark_cash_refunded(refund.id, payer)  # only the owner hands cash back
    done = await mark_cash_refunded(refund.id, payee)
    assert done.status == "cash_done"
    rows = await session.scalars(select(Payment).where(Payment.id == p.id))
    payment = rows.one()
    await session.refresh(payment)
    assert payment.status == "refunded"


async def test_unpaid_payments_cannot_be_refunded(env):  # noqa: F811
    booking, payer, payee = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 5000, "cash", "k1")
    with pytest.raises(ApiError) as err:
        await issue_refund(p.id, 100, None)
    assert err.value.code == "NOT_REFUNDABLE"


async def test_a_pending_refund_completes_on_the_webhook(env, session):  # noqa: F811
    from tests.test_webhooks import _webhook

    fake, client = env
    fake.refund_status = "pending"
    p, paid, payer = await _upi(fake)
    await _verify(client, p, paid, payer)
    refund = await issue_refund(p.id, 30000, uuid.uuid4())
    assert refund.status == "pending"
    entity = {"id": refund.razorpay_refund_id, "amount": 30000, "status": "processed"}
    first = await _webhook(client, "refund.processed", "refund", entity)
    again = await _webhook(client, "refund.processed", "refund", entity)
    assert first.json()["status"] == "processed" and again.json()["status"] == "processed"
    payment = await session.get(Payment, p.id)
    await session.refresh(payment)
    assert payment.status == "refunded" and payment.refunded_paise == 30000
    assert (await ledger.trial_balance(session)).balanced
