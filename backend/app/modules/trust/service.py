"""Trust scores, 0-100, one as lender and one as renter (the plan's formula).

    Lender = 100 × (0.70·R + 0.15·C + 0.15·A)
    Renter = 100 × (0.50·R + 0.20·P + 0.10·D + 0.10·C + 0.10·A)

R: average overall rating of the last 20 reviews in that role, scaled 0-1.
P: on-time returns, losing value with every hour late over a day.
D: share of rentals without a damage charge against the renter.
C: penalises cancellations (twice their share of trades).
A: account age, full after 180 days.
Moderator penalties are subtracted; nothing shows until 5 completed trades."""

import uuid
from dataclasses import dataclass

from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import get_account

from app.core.clock import now
from app.core.config import get_settings
from app.modules.bookings.models import Booking, Cancellation
from app.modules.reviews.models import Review
from app.modules.trust.models import TrustScore

LAST_REVIEWS = 20
SHOW_AFTER_TRADES = 5
FULL_AGE_DAYS = 180
NEUTRAL = 0.5  # R before any review


@dataclass
class Inputs:
    completed_trades: int
    cancellations: int
    lender_ratings: list[float]
    renter_ratings: list[float]
    punctuality: float
    damage_free: float
    age_days: float
    lender_penalty: int = 0
    renter_penalty: int = 0


def _scaled(ratings: list[float]) -> float:
    return (sum(ratings) / len(ratings) - 1) / 4 if ratings else NEUTRAL


def _clamp(value: float) -> int:
    return max(0, min(100, round(value)))


def scores(i: Inputs) -> tuple[int | None, int | None]:
    w = get_settings()
    trades = i.completed_trades + i.cancellations
    c = 1 - min(1.0, 2 * i.cancellations / trades) if trades else 1.0
    a = min(1.0, i.age_days / FULL_AGE_DAYS)
    lender = 100 * (
        w.trust_lender_r * _scaled(i.lender_ratings) + w.trust_lender_c * c + w.trust_lender_a * a
    )
    renter = 100 * (
        w.trust_renter_r * _scaled(i.renter_ratings)
        + w.trust_renter_p * i.punctuality
        + w.trust_renter_d * i.damage_free
        + w.trust_renter_c * c
        + w.trust_renter_a * a
    )
    if i.completed_trades < SHOW_AFTER_TRADES:
        return None, None
    return _clamp(lender - i.lender_penalty), _clamp(renter - i.renter_penalty)


async def penalties(session: AsyncSession, account_id: uuid.UUID) -> tuple[int, int]:
    """(lender, renter) points moderators have taken off. Filled in by moderation."""
    return 0, 0


async def _ratings(session: AsyncSession, account_id: uuid.UUID, role: str) -> list[float]:
    rows = await session.scalars(
        select(Review.overall)
        .where(
            Review.reviewee_id == account_id,
            Review.reviewee_role == role,
            Review.revealed_at.is_not(None),
            Review.removed_at.is_(None),
        )
        .order_by(Review.created_at.desc())
        .limit(LAST_REVIEWS)
    )
    return [float(r) for r in rows]


async def gather(session: AsyncSession, account_id: uuid.UUID) -> Inputs:
    party = or_(Booking.renter_id == account_id, Booking.owner_id == account_id)
    completed = await session.scalar(
        select(func.count()).where(party, Booking.status == "completed")
    )
    cancellations = await session.scalar(
        select(func.count()).where(Cancellation.by_id == account_id)
    )
    rentals = list(
        await session.execute(
            select(Booking.end_at, Booking.return_completed_at, Booking.damage_paise).where(
                Booking.renter_id == account_id,
                Booking.kind == "rent",
                Booking.return_completed_at.is_not(None),
            )
        )
    )
    if rentals:
        lateness = [
            max(0.0, 1 - max(0.0, (r.return_completed_at - r.end_at).total_seconds() / 3600) / 24)
            for r in rentals
        ]
        punctuality = sum(lateness) / len(lateness)
        damage_free = 1 - min(1.0, sum(1 for r in rentals if r.damage_paise > 0) / len(rentals))
    else:
        punctuality = damage_free = 1.0
    account = await get_account(account_id)
    age = (now() - account.created_at).total_seconds() / 86400 if account else 0.0
    lender_penalty, renter_penalty = await penalties(session, account_id)
    return Inputs(
        completed_trades=completed or 0,
        cancellations=cancellations or 0,
        lender_ratings=await _ratings(session, account_id, "lender"),
        renter_ratings=await _ratings(session, account_id, "renter"),
        punctuality=punctuality,
        damage_free=damage_free,
        age_days=age,
        lender_penalty=lender_penalty,
        renter_penalty=renter_penalty,
    )


def _avg(ratings: list[float]) -> float | None:
    return round(sum(ratings) / len(ratings), 2) if ratings else None


async def recompute(session: AsyncSession, *account_ids: uuid.UUID) -> None:
    """Refresh the stored scores. Called when reviews are revealed, a return
    completes, a booking is cancelled or a ruling lands."""
    for account_id in dict.fromkeys(account_ids):
        inputs = await gather(session, account_id)
        lender, renter = scores(inputs)
        values = {
            "lender_score": lender,
            "renter_score": renter,
            "lender_rating": _avg(inputs.lender_ratings),
            "renter_rating": _avg(inputs.renter_ratings),
            "lender_reviews": len(inputs.lender_ratings),
            "renter_reviews": len(inputs.renter_ratings),
            "completed_trades": inputs.completed_trades,
            "cancellations": inputs.cancellations,
            "updated_at": now(),
        }
        await session.execute(
            insert(TrustScore)
            .values(account_id=account_id, **values)
            .on_conflict_do_update(index_elements=[TrustScore.account_id], set_=values)
        )
