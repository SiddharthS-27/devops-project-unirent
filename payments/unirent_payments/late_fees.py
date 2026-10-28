"""The late-fee rule and the one calculation everyone uses.

Zero within the grace period. After it: the base fee, plus the hourly
percentage of the booking's rent for every full hour past the grace period,
rounded to the nearest rupee. With a ₹50 rental, ₹10 base and 2%, three hours
past the grace period cost ₹10 + 3 × ₹1 = ₹13."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from unirent_security.errors import ApiError

from unirent_payments import db
from unirent_payments.models import LateFeeRule


@dataclass(frozen=True)
class Rule:
    id: uuid.UUID
    version: int
    grace_minutes: int
    base_fee_paise: int
    hourly_percent_bp: int
    effective_from: datetime


def _rule(row: LateFeeRule) -> Rule:
    return Rule(
        id=row.id,
        version=row.version,
        grace_minutes=row.grace_minutes,
        base_fee_paise=row.base_fee_paise,
        hourly_percent_bp=row.hourly_percent_bp,
        effective_from=row.effective_from,
    )


async def current_late_fee_rule() -> Rule:
    async with db.sessionmaker()() as session:
        row = await session.scalar(
            select(LateFeeRule)
            .where(LateFeeRule.effective_from <= datetime.now(UTC))
            .order_by(LateFeeRule.effective_from.desc(), LateFeeRule.version.desc())
            .limit(1)
        )
    if row is None:
        raise ApiError(500, "NO_LATE_FEE_RULE", "No late-fee rule is set")
    return _rule(row)


async def get_rule(rule_id: uuid.UUID) -> Rule:
    async with db.sessionmaker()() as session:
        row = await session.get(LateFeeRule, rule_id)
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Late-fee rule not found")
    return _rule(row)


def _round_to_rupee(paise: int) -> int:
    return ((paise + 50) // 100) * 100


def calculate(rule: Rule, rent_paise: int, overdue_minutes: int) -> int:
    """`overdue_minutes` counts from the booking's end time."""
    past_grace = overdue_minutes - rule.grace_minutes
    if past_grace <= 0:
        return 0
    hours = past_grace // 60
    hourly = rent_paise * rule.hourly_percent_bp * hours // 10_000
    return _round_to_rupee(rule.base_fee_paise + hourly)


async def late_fee(rent_paise: int, overdue_minutes: int, rule_id: uuid.UUID) -> int:
    return calculate(await get_rule(rule_id), rent_paise, overdue_minutes)
