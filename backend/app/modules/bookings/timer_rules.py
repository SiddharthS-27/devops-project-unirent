"""What happens when each kind of timer fires. Every rule rechecks the booking,
because things move on between scheduling and firing (an answered request, an
extension, an early return); then it does nothing."""

from collections.abc import Awaitable, Callable

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.clock import now
from app.core.outbox import emit
from app.modules.bookings import rental, service, timers
from app.modules.bookings.events import payload
from app.modules.bookings.models import Booking
from app.modules.bookings.state import record

Rule = Callable[[AsyncSession, Booking], Awaitable[bool]]


async def _pickup_reminder(session: AsyncSession, booking: Booking) -> bool:
    if booking.status != "approved":
        return False
    emit(session, "PickupReminderDue", booking.id, payload(booking))
    return True


async def _return_reminder(session: AsyncSession, booking: Booking) -> bool:
    if booking.status != "active":
        return False
    emit(session, "ReturnReminderDue", booking.id, payload(booking))
    return True


async def _escalation_unlock(session: AsyncSession, booking: Booking) -> bool:
    if booking.status != "overdue":
        return False
    emit(session, "OverdueEscalationAvailable", booking.id, payload(booking))
    return True


async def _stalled_proceed(session: AsyncSession, booking: Booking) -> bool:
    """24 hours after the return code with no Proceed: the moderators take it up."""
    if booking.status != "returning" or booking.proceeded_at is not None:
        return False
    if booking.escalated_at is None:
        booking.escalated_at = now()
    record(session, booking, None, "system", "stalled_proceed")
    return True


RULES: dict[str, Rule] = {
    timers.REQUEST_EXPIRY: service.expire,
    timers.PICKUP_REMINDER: _pickup_reminder,
    timers.RETURN_REMINDER: _return_reminder,
    timers.OVERDUE_START: rental.mark_overdue,
    timers.OVERDUE_ALERT: rental.overdue_alert,
    timers.ESCALATION_UNLOCK: _escalation_unlock,
    timers.STALLED_PROCEED: _stalled_proceed,
}
