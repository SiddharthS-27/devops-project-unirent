"""The active rental: extensions, going overdue, live late fees and escalation."""

import uuid
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import PaymentView, late_fee, payment_status, start_payment
from unirent_payments.late_fees import get_rule
from unirent_security import AccountContext

from app.core.clock import now
from app.core.errors import ApiError, not_found
from app.core.outbox import emit
from app.core.timers import cancel_timers, schedule
from app.modules.bookings import pricing, timers
from app.modules.bookings.events import payload
from app.modules.bookings.models import Booking, Extension
from app.modules.bookings.service import REMINDER_BEFORE, get_booking, require_party
from app.modules.bookings.state import record, require_status, transition
from app.modules.listings.models import Listing

ESCALATION_AFTER = timedelta(hours=1)
OVERDUE_ALERT_EVERY = timedelta(hours=1)


def overdue_minutes(booking: Booking) -> int:
    if booking.end_at is None:
        return 0
    return max(0, int((now() - booking.end_at).total_seconds() // 60))


async def live_late_fee(booking: Booking) -> int:
    """The late fee so far, or the frozen one once the item is back."""
    if booking.late_fee_paise is not None:
        return booking.late_fee_paise
    if booking.kind != "rent" or booking.late_fee_rule_id is None:
        return 0
    return await late_fee(booking.amount_paise, overdue_minutes(booking), booking.late_fee_rule_id)


async def grace(booking: Booking) -> timedelta:
    if booking.late_fee_rule_id is None:
        return timedelta(0)
    return timedelta(minutes=(await get_rule(booking.late_fee_rule_id)).grace_minutes)


def _reschedule_end(session: AsyncSession, booking: Booking, grace_period: timedelta) -> None:
    assert booking.end_at is not None
    if booking.end_at - REMINDER_BEFORE > now():
        schedule(session, timers.RETURN_REMINDER, booking.id, booking.end_at - REMINDER_BEFORE)
    schedule(session, timers.OVERDUE_START, booking.id, booking.end_at + grace_period)


async def request_extension(
    session: AsyncSession, booking_id: uuid.UUID, renter: AccountContext, new_end_at
) -> Extension:
    booking = await get_booking(session, booking_id, renter, lock=True)
    require_party(booking, renter, "renter")
    require_status(booking, "active")
    assert booking.end_at is not None
    if new_end_at <= booking.end_at:
        raise ApiError(422, "EXTENSION_TOO_SHORT", "Pick a time after the current end time")
    if pricing.rental_hours(booking.start_at, new_end_at) > pricing.MAX_DAYS * 24:  # type: ignore[arg-type]
        raise ApiError(422, "PERIOD_TOO_LONG", f"Rent for at most {pricing.MAX_DAYS} days")
    pending = await session.scalar(
        select(Extension.id).where(
            Extension.booking_id == booking.id, Extension.status == "requested"
        )
    )
    if pending is not None:
        raise ApiError(409, "EXTENSION_PENDING", "Wait for the owner to answer the last request")
    listing = await session.get(Listing, booking.listing_id)
    extra_hours = pricing.rental_hours(booking.end_at, new_end_at)
    extension = Extension(
        id=uuid.uuid4(),
        booking_id=booking.id,
        old_end_at=booking.end_at,
        new_end_at=new_end_at,
        status="requested",
        amount_paise=pricing.rent_for(listing, extra_hours),  # type: ignore[arg-type]
        created_at=now(),
    )
    session.add(extension)
    record(session, booking, renter.id, "renter", "extension_requested")
    emit(
        session,
        "ExtensionRequested",
        booking.id,
        payload(booking, extension_id=str(extension.id), new_end_at=new_end_at.isoformat()),
    )
    return extension


async def _extension(session: AsyncSession, booking: Booking, extension_id: uuid.UUID) -> Extension:
    extension = await session.get(Extension, extension_id, with_for_update=True)
    if extension is None or extension.booking_id != booking.id:
        raise not_found("Extension")
    return extension


async def decide_extension(
    session: AsyncSession,
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    owner: AccountContext,
    approve: bool,
) -> Extension:
    booking = await get_booking(session, booking_id, owner, lock=True)
    require_party(booking, owner, "owner")
    require_status(booking, "active")
    extension = await _extension(session, booking, extension_id)
    if extension.status != "requested":
        raise ApiError(409, "EXTENSION_DECIDED", f"Already {extension.status}")
    extension.status = "approved" if approve else "declined"
    extension.decided_at = now()
    if approve:
        booking.end_at = extension.new_end_at
        booking.amount_paise += extension.amount_paise
        try:
            await session.flush()
        except IntegrityError:
            await session.rollback()
            raise ApiError(409, "SLOT_TAKEN", "Someone else has booked that time") from None
        await cancel_timers(session, booking.id, [timers.RETURN_REMINDER, timers.OVERDUE_START])
        _reschedule_end(session, booking, await grace(booking))
    record(session, booking, owner.id, "owner", f"extension_{extension.status}")
    emit(
        session,
        "ExtensionDecided",
        booking.id,
        payload(booking, extension_id=str(extension.id), decision=extension.status),
    )
    return extension


async def pay_extension(
    session: AsyncSession,
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    renter: AccountContext,
    method: str,
    idempotency_key: str,
) -> PaymentView | None:
    """UPI now, or cash at return (added to the return charges)."""
    booking = await get_booking(session, booking_id, renter, lock=True)
    require_party(booking, renter, "renter")
    extension = await _extension(session, booking, extension_id)
    if extension.status != "approved":
        raise ApiError(409, "EXTENSION_NOT_APPROVED", "The owner hasn't approved this extension")
    if method == "cash":
        extension.pay_in_cash_at_return = True
        record(session, booking, renter.id, "renter", "extension_cash_at_return")
        await session.commit()
        return None
    return await start_payment(
        booking.id,
        "extension",
        booking.renter_id,
        booking.owner_id,
        extension.amount_paise,
        "upi",
        idempotency_key,
        purpose_ref=extension.id,
        items=[{"label": "Extension", "amount_paise": extension.amount_paise}],
    )


async def unpaid_cash_extensions(session: AsyncSession, booking: Booking) -> int:
    """Approved extensions not paid by UPI: they are owed at return."""
    total = 0
    rows = await session.scalars(
        select(Extension).where(Extension.booking_id == booking.id, Extension.status == "approved")
    )
    for extension in rows:
        paid = await payment_status(booking.id, "extension", extension.id)
        if paid is None or not paid.is_paid:
            total += extension.amount_paise
    return total


async def mark_overdue(session: AsyncSession, booking: Booking) -> bool:
    """End time plus grace has passed with the item still out."""
    if booking.status != "active" or booking.end_at is None:
        return False
    overdue_at = booking.end_at + await grace(booking)
    if now() < overdue_at:
        return False  # extended since the timer was set
    transition(session, booking, "overdue", actor_id=None, actor_role="system", action="overdue")
    # When the rule made it overdue, not when the timer fired: they differ after
    # a late timer pass or a clock jump, and escalation counts from this.
    booking.overdue_since = overdue_at
    fee = await live_late_fee(booking)
    emit(session, "RentalOverdue", booking.id, payload(booking, late_fee_paise=fee))
    schedule(session, timers.OVERDUE_ALERT, booking.id, now() + OVERDUE_ALERT_EVERY)
    schedule(session, timers.ESCALATION_UNLOCK, booking.id, overdue_at + ESCALATION_AFTER)
    return True


async def overdue_alert(session: AsyncSession, booking: Booking) -> bool:
    """Hourly while the item is still out."""
    if booking.status != "overdue":
        return False
    fee = await live_late_fee(booking)
    emit(session, "RentalOverdue", booking.id, payload(booking, late_fee_paise=fee))
    schedule(session, timers.OVERDUE_ALERT, booking.id, now() + OVERDUE_ALERT_EVERY)
    return True


def escalation_available_at(booking: Booking):
    return booking.overdue_since + ESCALATION_AFTER if booking.overdue_since else None


async def escalate(
    session: AsyncSession, booking_id: uuid.UUID, owner: AccountContext, note: str | None
) -> Booking:
    """One hour into overdue, the owner can hand the case to the moderators."""
    booking = await get_booking(session, booking_id, owner, lock=True)
    require_party(booking, owner, "owner")
    require_status(booking, "overdue")
    available = escalation_available_at(booking)
    if available is None or now() < available:
        raise ApiError(
            409, "ESCALATION_NOT_YET", "You can escalate an hour into overdue; use Help before that"
        )
    if booking.escalated_at is None:
        booking.escalated_at = now()
        booking.escalation_note = note
        record(session, booking, owner.id, "owner", "escalate", details={"note": note})
    return booking
