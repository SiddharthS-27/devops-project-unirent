"""The payments merge gate from the plan: no action is ever charged twice."""

import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from tests.helpers import ready_payee
from tests.test_webhooks import _upi, _verify, _webhook, env  # noqa: F401 - fixture
from unirent_payments import ledger
from unirent_payments.models import LedgerEntry, Payment
from unirent_payments.payments import start_payment


async def test_same_key_twice_creates_one_payment(env, session):  # noqa: F811
    payee, _ = await ready_payee()
    booking, payer = uuid.uuid4(), uuid.uuid4()
    results = await asyncio.gather(
        *(start_payment(booking, "rent", payer, payee, 1000, "upi", "same-key") for _ in range(4))
    )
    assert len({r.id for r in results}) == 1
    count = await session.scalar(select(func.count()).where(Payment.booking_ref == booking))
    assert count == 1


async def test_verify_and_webhook_racing_capture_once(env, session):  # noqa: F811
    fake, client = env
    p, paid, payer = await _upi(fake)
    await asyncio.gather(
        _verify(client, p, paid, payer),
        _webhook(client, "payment.captured", "payment", paid),
        _webhook(client, "payment.captured", "payment", paid),
    )
    lines = await session.scalar(select(func.count()).where(LedgerEntry.payment_id == p.id))
    assert lines == 2


async def test_the_ledger_balances_after_everything(session):
    balance = await ledger.trial_balance(session)
    assert balance.balanced, balance


pytestmark = pytest.mark.payments
