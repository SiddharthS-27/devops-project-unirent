"""Blind, compulsory reviews. Each side reviews once; reviews stay hidden until
both are in or 24 hours after the first, then the booking completes."""

import uuid
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import AccountContext

from app.core.clock import now
from app.core.errors import ApiError
from app.core.outbox import emit
from app.core.timers import cancel_timers, schedule
from app.modules.bookings import timers
from app.modules.bookings.events import payload
from app.modules.bookings.models import Booking
from app.modules.bookings.service import get_booking
from app.modules.bookings.state import record, transition
from app.modules.reviews.models import Review
from app.modules.trust import service as trust

RELEASE_AFTER = timedelta(hours=24)

PARAMETERS: dict[str, list[tuple[str, str]]] = {
    "renter": [
        ("item_care", "Item care"),
        ("return_punctuality", "Return punctuality"),
        ("communication", "Communication"),
    ],
    "lender": [
        ("item_matches_description", "Item matches description"),
        ("item_condition", "Item condition"),
        ("handover_punctuality", "Handover punctuality"),
        ("communication", "Communication"),
    ],
    "renter_sale": [
        ("handover_punctuality", "Handover punctuality"),
        ("payment_promptness", "Payment promptness"),
        ("communication", "Communication"),
    ],
    "lender_sale": [
        ("item_matches_description", "Item matches description"),
        ("item_condition", "Item condition"),
        ("handover_punctuality", "Handover punctuality"),
        ("communication", "Communication"),
    ],
    "cancellation": [("overall", "Overall")],
}


def review_type_for(booking: Booking, reviewer_role: str) -> str:
    """The owner rates the renter; the renter rates the owner (as lender)."""
    reviewing = "renter" if reviewer_role == "owner" else "lender"
    return reviewing if booking.kind == "rent" else f"{reviewing}_sale"


def overall(ratings: dict[str, int]) -> Decimal:
    """Equal weights: the plain average, to two places."""
    mean = Decimal(sum(ratings.values())) / len(ratings)
    return mean.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def check_ratings(review_type: str, ratings: dict[str, int]) -> None:
    expected = {key for key, _ in PARAMETERS[review_type]}
    if set(ratings) != expected:
        raise ApiError(
            422,
            "INVALID_RATINGS",
            "Rate every parameter",
            details={"expected": sorted(expected)},
        )
    if any(not isinstance(v, int) or not 1 <= v <= 5 for v in ratings.values()):
        raise ApiError(422, "INVALID_RATINGS", "Ratings are 1 to 5 stars")


async def reviews_of(session: AsyncSession, booking_id: uuid.UUID) -> list[Review]:
    rows = await session.scalars(select(Review).where(Review.booking_id == booking_id))
    return list(rows)


async def submit(
    session: AsyncSession,
    booking_id: uuid.UUID,
    actor: AccountContext,
    ratings: dict[str, int],
    comment: str,
) -> Booking:
    booking = await get_booking(session, booking_id, actor, lock=True)
    role = booking.role_of(actor.id)
    if role is None:
        raise ApiError(403, "NOT_YOUR_STEP", "Only the two sides review")
    if booking.status != "awaiting_reviews":
        raise ApiError(409, "BOOKING_STATE", "Reviews aren't open for this booking")
    existing = await reviews_of(session, booking.id)
    if any(r.reviewer_id == actor.id for r in existing):
        raise ApiError(409, "ALREADY_REVIEWED", "You already reviewed this")
    review_type = review_type_for(booking, role)
    check_ratings(review_type, ratings)
    session.add(
        Review(
            id=uuid.uuid4(),
            booking_id=booking.id,
            reviewer_id=actor.id,
            reviewee_id=booking.owner_id if role == "renter" else booking.renter_id,
            review_type=review_type,
            reviewee_role="lender" if role == "renter" else "renter",
            ratings=ratings,
            overall=overall(ratings),
            comment=comment,
            created_at=now(),
        )
    )
    record(session, booking, actor.id, role, "review")
    await session.flush()
    if existing:  # the other side was already in
        await reveal(session, booking)
    else:
        schedule(session, timers.REVIEW_RELEASE, booking.id, now() + RELEASE_AFTER)
        emit(session, "ReviewPending", booking.id, payload(booking, waiting_for=_other(role)))
    return booking


def _other(role: str) -> str:
    return "owner" if role == "renter" else "renter"


async def reveal(session: AsyncSession, booking: Booking) -> bool:
    """Show whatever reviews are in and complete the booking."""
    if booking.status != "awaiting_reviews":
        return False
    for review in await reviews_of(session, booking.id):
        review.revealed_at = review.revealed_at or now()
    transition(session, booking, "completed", actor_id=None, actor_role="system", action="reveal")
    booking.completed_at = now()
    await cancel_timers(session, booking.id, timers.REVIEW_RELEASE)
    emit(session, "ReviewsRevealed", booking.id, payload(booking))
    await on_completed(session, booking)
    return True


async def on_completed(session: AsyncSession, booking: Booking) -> None:
    await session.flush()
    await trust.recompute(session, booking.renter_id, booking.owner_id)


async def release(session: AsyncSession, booking: Booking) -> bool:
    """The 24-hour timer: the waiting side is released."""
    return await reveal(session, booking)
