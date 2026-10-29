"""The booking state machine. Every status change goes through transition(),
which checks the move is allowed and appends a booking_events row."""

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.clock import now
from app.core.errors import ApiError
from app.core.metrics import BOOKING_TRANSITIONS
from app.modules.bookings.models import Booking, BookingEvent

# from -> allowed targets, for rentals. Sales skip active, overdue and return:
# approved goes straight to awaiting_reviews at the handover.
TRANSITIONS: dict[str, set[str]] = {
    "requested": {"approved", "declined", "withdrawn", "expired"},
    "approved": {"active", "awaiting_reviews", "cancelled"},
    "active": {"overdue", "returning"},
    "overdue": {"returning"},
    "returning": {"in_appeal", "awaiting_reviews"},
    # A rental's ruling returns it to the return, where the renter pays the ruled
    # charge and the owner taps Proceed; a sale goes back to where it was.
    "in_appeal": {"returning", "awaiting_reviews", "completed"},
    "awaiting_reviews": {"completed", "in_appeal"},
    "completed": {"in_appeal"},
    "declined": set(),
    "withdrawn": set(),
    "expired": set(),
    "cancelled": set(),
}
SALE_ONLY = {
    ("in_appeal", "awaiting_reviews"),
    ("in_appeal", "completed"),
    ("approved", "awaiting_reviews"),
    ("awaiting_reviews", "in_appeal"),
    ("completed", "in_appeal"),
}
RENT_ONLY = {("approved", "active"), ("in_appeal", "returning")}

GROUPS: dict[str, tuple[str, ...]] = {
    "pending": ("requested",),
    "upcoming": ("approved",),
    "active": ("active", "overdue", "returning", "in_appeal", "awaiting_reviews"),
    "past": ("completed", "declined", "withdrawn", "expired"),
    "cancelled": ("cancelled",),
}


def can_move(booking: Booking, to: str) -> bool:
    if to not in TRANSITIONS[booking.status]:
        return False
    move = (booking.status, to)
    if booking.kind == "rent" and move in SALE_ONLY:
        return False
    return not (booking.kind == "sale" and move in RENT_ONLY)


def require_status(booking: Booking, *statuses: str) -> None:
    if booking.status not in statuses:
        raise ApiError(
            409,
            "BOOKING_STATE",
            f"This booking is {booking.status.replace('_', ' ')}",
            details={"status": booking.status},
        )


def transition(
    session: AsyncSession,
    booking: Booking,
    to: str,
    *,
    actor_id: uuid.UUID | None,
    actor_role: str,
    action: str,
    details: dict[str, Any] | None = None,
) -> None:
    """Move the (row-locked) booking and record who moved it."""
    if not can_move(booking, to):
        raise ApiError(
            409,
            "BOOKING_STATE",
            f"A {booking.status.replace('_', ' ')} booking can't become {to.replace('_', ' ')}",
            details={"status": booking.status},
        )
    record(session, booking, actor_id, actor_role, action, to=to, details=details)
    BOOKING_TRANSITIONS.labels(booking.status, to).inc()
    booking.status = to
    booking.updated_at = now()


def record(
    session: AsyncSession,
    booking: Booking,
    actor_id: uuid.UUID | None,
    actor_role: str,
    action: str,
    *,
    to: str | None = None,
    details: dict[str, Any] | None = None,
) -> None:
    """Append to the booking's history (transitions and non-moving steps alike)."""
    session.add(
        BookingEvent(
            booking_id=booking.id,
            at=now(),
            actor_id=actor_id,
            actor_role=actor_role,
            action=action,
            from_status=booking.status,
            to_status=to or booking.status,
            details=details or {},
        )
    )
