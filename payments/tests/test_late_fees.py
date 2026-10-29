import uuid
from datetime import UTC, datetime

import pytest

from unirent_payments.late_fees import Rule, calculate, current_late_fee_rule

RULE = Rule(uuid.uuid4(), 1, 30, 1000, 200, datetime(2026, 1, 1, tzinfo=UTC))


@pytest.mark.parametrize(
    "rent, overdue_minutes, fee",
    [
        (5000, 0, 0),  # on time
        (5000, 30, 0),  # still inside the grace period
        (5000, 31, 1000),  # just past it: the base fee
        (5000, 89, 1000),  # not yet a full hour past the grace period
        (5000, 90, 1100),  # one full hour: 2% of ₹50 is ₹1
        (5000, 30 + 180, 1300),  # the plan's example: three hours, ₹13
        (30000, 30 + 120, 2200),  # ₹300 rent, two hours: ₹10 + ₹12
        (12345, 30 + 60, 1200),  # ₹10 + ₹2.469 rounds to ₹12
        (12345, 30 + 120, 1500),  # ₹10 + ₹4.938 rounds to ₹15
    ],
)
def test_late_fee_table(rent, overdue_minutes, fee):
    assert calculate(RULE, rent, overdue_minutes) == fee


def test_zero_grace_charges_from_the_first_minute():
    rule = Rule(uuid.uuid4(), 2, 0, 500, 100, RULE.effective_from)
    assert calculate(rule, 10000, 1) == 500
    assert calculate(rule, 10000, 60) == 600


async def test_the_starting_rule_is_seeded(session):
    rule = await current_late_fee_rule()
    assert rule.grace_minutes >= 0 and rule.base_fee_paise >= 0


async def test_a_new_version_applies_to_new_approvals_only(session):
    import uuid as _uuid

    from unirent_payments import db
    from unirent_payments.late_fees import get_rule, history, set_rule

    before = await current_late_fee_rule()
    new = await set_rule(15, 2000, 300, _uuid.uuid4())
    assert new.version == before.version + 1
    assert (await current_late_fee_rule()).id == new.id
    assert (await get_rule(before.id)).grace_minutes == before.grace_minutes
    assert (await history())[0].id == new.id
    await set_rule(30, 1000, 200, _uuid.uuid4())  # leave the default in force for other tests
    await db.reset()
