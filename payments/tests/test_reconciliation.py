import uuid
from datetime import UTC, datetime

import pytest

from tests.test_webhooks import _upi, _verify, env  # noqa: F401 - fixture
from unirent_payments.models import Payment
from unirent_payments.reconciliation import compare, run

pytestmark = pytest.mark.reconciliation


async def _captured(fake, client, session):
    p, paid, payer = await _upi(fake)
    await _verify(client, p, paid, payer)
    payment = await session.get(Payment, p.id)
    await session.refresh(payment)
    return payment, paid


async def test_matching_records_report_nothing(env, session):  # noqa: F811
    fake, client = env
    payment, paid = await _captured(fake, client, session)
    report = await compare(session, [payment], {paid["id"]: paid}, [], {})
    assert report.mismatches == []


async def test_every_kind_of_disagreement_is_reported(env, session):  # noqa: F811
    fake, client = env
    payment, paid = await _captured(fake, client, session)
    stranger = {"id": "pay_unknown", "amount": 999, "status": "captured", "order_id": "x"}
    wrong = {**paid, "amount": paid["amount"] + 100}
    report = await compare(session, [payment], {paid["id"]: wrong, "pay_unknown": stranger}, [], {})
    kinds = sorted(m["kind"] for m in report.mismatches)
    assert kinds == ["amount_differs", "missing_in_ledger"]

    fake.payments[paid["id"]]["transfers"] = []
    report = await compare(session, [payment], {paid["id"]: paid}, [], {})
    assert [m["kind"] for m in report.mismatches] == ["transfer_missing"]


async def test_a_run_is_recorded_with_totals(env):  # noqa: F811
    record = await run(datetime.now(UTC).date(), triggered_by=str(uuid.uuid4()))
    assert record.status == "done"
    assert {"payments_checked", "mismatches", "settlements_available"} <= set(record.totals)
