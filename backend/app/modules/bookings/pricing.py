"""What a rental costs. The backend decides every amount; the app only shows it."""

import math
from datetime import datetime, timedelta

from app.core.clock import now
from app.core.errors import ApiError
from app.modules.listings.models import Listing

MIN_HOURS = 1
MAX_DAYS = 30
START_GRACE = timedelta(minutes=5)


def rental_hours(start_at: datetime, end_at: datetime) -> int:
    """Whole hours, rounded up: 2h10m is billed as 3 hours."""
    return math.ceil((end_at - start_at).total_seconds() / 3600)


def rent_for(listing: Listing, hours: int) -> int:
    """The cheapest mix of the listing's rates. With both rates, full days use the
    daily rate and the remaining hours the hourly rate, capped at one more day."""
    day, hour = listing.price_per_day_paise, listing.price_per_hour_paise
    if day and hour:
        days, rest = divmod(hours, 24)
        return days * day + min(rest * hour, day)
    if day:
        return math.ceil(hours / 24) * day
    return hours * (hour or 0)


def check_period(start_at: datetime | None, end_at: datetime | None) -> int:
    if start_at is None or end_at is None:
        raise ApiError(422, "PERIOD_REQUIRED", "Pick a start and end time")
    if start_at.tzinfo is None or end_at.tzinfo is None:
        raise ApiError(422, "TIMEZONE_REQUIRED", "Send times with a timezone")
    if start_at < now() - START_GRACE:
        raise ApiError(422, "START_IN_PAST", "The start time has passed")
    hours = rental_hours(start_at, end_at)
    if end_at <= start_at or hours < MIN_HOURS:
        raise ApiError(422, "PERIOD_TOO_SHORT", "Rent for at least an hour")
    if hours > MAX_DAYS * 24:
        raise ApiError(422, "PERIOD_TOO_LONG", f"Rent for at most {MAX_DAYS} days")
    return hours


def quote(
    listing: Listing, start_at: datetime | None, end_at: datetime | None
) -> tuple[int | None, int]:
    """(hours, amount). Sales have no period and cost the listed price."""
    if listing.kind == "sale":
        if start_at or end_at:
            raise ApiError(422, "NO_PERIOD_FOR_SALE", "Purchases have no rental period")
        return None, listing.sale_price_paise or 0
    hours = check_period(start_at, end_at)
    return hours, rent_for(listing, hours)


def quote_locked(listing: Listing, start_at: datetime, end_at: datetime) -> tuple[int, int]:
    """The rent at approval, from the listing's current rates."""
    hours = rental_hours(start_at, end_at)
    return hours, rent_for(listing, hours)
