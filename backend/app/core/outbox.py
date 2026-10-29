"""Outbox writer. Events are written in the caller's transaction, so an event
exists exactly when the change it describes was committed."""

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.clock import now
from app.core.models import OutboxEvent

BOOKING_EVENTS = {
    "BookingRequested",
    "BookingDecided",
    "BookingWithdrawn",
    "BookingCancelled",
    "PickupReminderDue",
    "PickupCompleted",
    "ExtensionRequested",
    "ExtensionDecided",
    "ReturnReminderDue",
    "RentalOverdue",
    "OverdueEscalationAvailable",
    "ReturnCompleted",
    "DamageChargeRecorded",
    "ReviewPending",
    "ReviewsRevealed",
}
LISTING_EVENTS = {"ListingPublished"}
MODERATION_EVENTS = {
    "AppealFiled",
    "AppealRuled",
    "RulingOverruled",
    "SupportReplyPosted",
    "AccountStatusChanged",
}


def topic_for(event_type: str) -> str:
    if event_type in BOOKING_EVENTS:
        return "bookings.events"
    if event_type in LISTING_EVENTS:
        return "listings.events"
    if event_type in MODERATION_EVENTS:
        return "moderation.events"
    raise ValueError(f"unknown event type {event_type!r}")


def emit(
    session: AsyncSession,
    type: str,
    aggregate_id: uuid.UUID | str,
    payload: dict[str, Any],
    version: int = 1,
) -> OutboxEvent:
    """Add an event to the session. It is published only if the session commits."""
    event = OutboxEvent(
        id=uuid.uuid4(),
        topic=topic_for(type),
        type=type,
        version=version,
        aggregate_id=str(aggregate_id),
        payload=payload,
        producer="backend",
        occurred_at=now(),
    )
    session.add(event)
    return event
