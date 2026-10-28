"""Event payloads. Every booking event carries enough for the push sender to
pick recipients and words without calling back."""

from typing import Any

from app.modules.bookings.models import Booking


def payload(booking: Booking, **extra: Any) -> dict[str, Any]:
    return {
        "booking_id": str(booking.id),
        "listing_id": str(booking.listing_id),
        "listing_title": booking.listing_title,
        "kind": booking.kind,
        "renter_id": str(booking.renter_id),
        "owner_id": str(booking.owner_id),
        "pickup_point": booking.pickup_point,
        "start_at": booking.start_at.isoformat() if booking.start_at else None,
        "end_at": booking.end_at.isoformat() if booking.end_at else None,
        **extra,
    }
