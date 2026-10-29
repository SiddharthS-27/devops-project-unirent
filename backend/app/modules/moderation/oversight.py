"""What moderators watch: escalations and risk flags."""

import uuid
from datetime import timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.clock import now
from app.modules.bookings.models import Booking, Cancellation
from app.modules.moderation.models import Appeal
from app.modules.staff.schemas import RiskFlag
from app.modules.trust.models import TrustScore

WINDOW = timedelta(days=30)
OVERDUE_FLAG = 3
CANCELLATION_FLAG = 3
DISPUTE_FLAG = 2
LOW_TRUST = 30
ESCALATE_OVERDUE_AFTER = timedelta(hours=1)
STALLED_AFTER = timedelta(hours=24)


async def escalated_bookings(session: AsyncSession) -> list[tuple[Booking, str]]:
    """Overdue an hour or more, escalated by the owner, or Proceed stalled 24 hours."""
    cutoff = now() - ESCALATE_OVERDUE_AFTER
    overdue = await session.scalars(
        select(Booking)
        .where(
            Booking.status == "overdue",
            or_(Booking.overdue_since <= cutoff, Booking.escalated_at.is_not(None)),
        )
        .order_by(Booking.overdue_since)
    )
    out = [(b, "owner_escalated" if b.escalated_at else "overdue") for b in overdue]
    stalled = await session.scalars(
        select(Booking)
        .where(
            Booking.status == "returning",
            Booking.proceeded_at.is_(None),
            Booking.return_completed_at <= now() - STALLED_AFTER,
        )
        .order_by(Booking.return_completed_at)
    )
    out += [(b, "stalled_proceed") for b in stalled]
    return out


async def risk_flags(
    session: AsyncSession, account_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[RiskFlag]]:
    """Repeated overdue returns, cancellations or disputes in 30 days; very low trust."""
    since = now() - WINDOW
    ids = list(set(account_ids))
    flags: dict[uuid.UUID, list[RiskFlag]] = {a: [] for a in ids}

    overdue = dict(
        (
            await session.execute(
                select(Booking.renter_id, func.count())
                .where(Booking.renter_id.in_(ids), Booking.overdue_since >= since)
                .group_by(Booking.renter_id)
            )
        ).all()
    )
    cancellations = dict(
        (
            await session.execute(
                select(Cancellation.by_id, func.count())
                .where(Cancellation.by_id.in_(ids), Cancellation.at >= since)
                .group_by(Cancellation.by_id)
            )
        ).all()
    )
    disputes: dict[uuid.UUID, int] = {}
    rows = await session.execute(
        select(Booking.renter_id, Booking.owner_id)
        .join(Appeal, Appeal.booking_id == Booking.id)
        .where(
            Appeal.created_at >= since,
            or_(Booking.renter_id.in_(ids), Booking.owner_id.in_(ids)),
        )
    )
    for renter_id, owner_id in rows:
        for party in (renter_id, owner_id):
            if party in flags:
                disputes[party] = disputes.get(party, 0) + 1
    trust = {
        row.account_id: row
        for row in await session.scalars(select(TrustScore).where(TrustScore.account_id.in_(ids)))
    }

    for account_id in ids:
        if overdue.get(account_id, 0) >= OVERDUE_FLAG:
            flags[account_id].append(
                RiskFlag(kind="overdue_returns", count=overdue[account_id], window_days=30)
            )
        if cancellations.get(account_id, 0) >= CANCELLATION_FLAG:
            flags[account_id].append(
                RiskFlag(kind="cancellations", count=cancellations[account_id], window_days=30)
            )
        if disputes.get(account_id, 0) >= DISPUTE_FLAG:
            flags[account_id].append(
                RiskFlag(kind="disputes", count=disputes[account_id], window_days=30)
            )
        lowest = _lowest_score(trust.get(account_id))
        if lowest is not None and lowest < LOW_TRUST:
            flags[account_id].append(RiskFlag(kind="low_trust", count=lowest, window_days=None))
    return flags


def _lowest_score(row: TrustScore | None) -> int | None:
    if row is None:
        return None
    scores = [s for s in (row.lender_score, row.renter_score) if s is not None]
    return min(scores) if scores else None


async def flagged_accounts(session: AsyncSession) -> list[uuid.UUID]:
    """Everyone with at least one flag, from the people active in the last 30 days.
    Most flags first, in a fixed order so paging through the list is stable."""
    since = now() - WINDOW
    recent = await session.scalars(
        select(Booking.renter_id)
        .where(Booking.updated_at >= since)
        .union(select(Booking.owner_id).where(Booking.updated_at >= since))
    )
    low = await session.scalars(
        select(TrustScore.account_id).where(
            or_(TrustScore.lender_score < LOW_TRUST, TrustScore.renter_score < LOW_TRUST)
        )
    )
    candidates = list(set(recent) | set(low))
    flags = await risk_flags(session, candidates)
    flagged = [a for a, f in flags.items() if f]
    return sorted(flagged, key=lambda a: (-len(flags[a]), str(a)))
