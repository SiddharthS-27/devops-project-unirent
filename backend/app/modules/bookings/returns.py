"""The return: renter's photos, the owner's inspection photos, the owner's code
typed by the renter, any agreed damage charge, the renter paying what is owed,
and the owner tapping Proceed."""

import uuid
from datetime import timedelta

from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import PaymentView, payment_status, start_payment
from unirent_security import AccountContext

from app.core.clock import now
from app.core.errors import ApiError
from app.core.outbox import emit
from app.core.timers import cancel_timers, schedule
from app.modules.bookings import rental, timers
from app.modules.bookings.events import payload
from app.modules.bookings.handover import photo_keys
from app.modules.bookings.models import Booking
from app.modules.bookings.service import get_booking, require_party
from app.modules.bookings.state import record, require_status, transition
from app.modules.listings.models import AssetEvent
from app.modules.trust import service as trust

STALLED_PROCEED_AFTER = timedelta(hours=24)


async def start_return(
    session: AsyncSession, booking_id: uuid.UUID, renter: AccountContext
) -> Booking:
    booking = await get_booking(session, booking_id, renter, lock=True)
    require_party(booking, renter, "renter")
    require_status(booking, "active", "overdue")
    transition(
        session,
        booking,
        "returning",
        actor_id=renter.id,
        actor_role="renter",
        action="start_return",
    )
    booking.return_started_at = now()
    await cancel_timers(session, booking.id, [timers.RETURN_REMINDER, timers.OVERDUE_START])
    return booking


async def code_ready(session: AsyncSession, booking: Booking) -> bool:
    photos = await photo_keys(session, booking.id)
    return bool(photos.get(("return", "renter")) and photos.get(("return", "owner")))


async def owner_may_inspect(session: AsyncSession, booking: Booking) -> None:
    """The renter's return photos come first, then the owner's inspection."""
    photos = await photo_keys(session, booking.id)
    if not photos.get(("return", "renter")):
        raise ApiError(409, "STEP_LOCKED", "Wait for the renter's return photos")


async def complete_return(session: AsyncSession, booking: Booking, renter: AccountContext) -> None:
    """The renter typed the owner's code: the item is back. The late fee stops here."""
    booking.late_fee_paise = await rental.live_late_fee(booking)
    booking.return_completed_at = now()
    record(
        session,
        booking,
        renter.id,
        "renter",
        "return_confirmed",
        details={"late_fee_paise": booking.late_fee_paise},
    )
    await cancel_timers(session, booking.id, [timers.OVERDUE_ALERT, timers.ESCALATION_UNLOCK])
    schedule(session, timers.STALLED_PROCEED, booking.id, now() + STALLED_PROCEED_AFTER)
    keys = await photo_keys(session, booking.id)
    session.add(
        AssetEvent(
            id=uuid.uuid4(),
            asset_id=booking.asset_id,
            at=now(),
            kind="returned",
            summary="Returned to the owner",
            booking_id=booking.id,
            photo_keys=keys.get(("return", "renter"), []) + keys.get(("return", "owner"), []),
        )
    )
    emit(
        session,
        "ReturnCompleted",
        booking.id,
        payload(booking, late_fee_paise=booking.late_fee_paise),
    )
    await session.flush()
    await trust.recompute(session, booking.renter_id)


def _require_item_back(booking: Booking) -> None:
    if booking.return_completed_at is None:
        raise ApiError(409, "STEP_LOCKED", "Confirm the return with the code first")


async def record_damage(
    session: AsyncSession, booking_id: uuid.UUID, owner: AccountContext, amount: int, text: str
) -> Booking:
    """The charge both sides agreed on. If they disagree, either side appeals instead."""
    booking = await get_booking(session, booking_id, owner, lock=True)
    require_party(booking, owner, "owner")
    require_status(booking, "returning")
    _require_item_back(booking)
    paid = await payment_status(booking.id, "return_charges")
    if paid is not None and paid.is_paid:
        raise ApiError(409, "ALREADY_PAID", "The return charges are already paid")
    booking.damage_paise = amount
    booking.damage_description = text
    record(session, booking, owner.id, "owner", "damage_charge", details={"amount_paise": amount})
    emit(session, "DamageChargeRecorded", booking.id, payload(booking, amount_paise=amount))
    session.add(
        AssetEvent(
            id=uuid.uuid4(),
            asset_id=booking.asset_id,
            at=now(),
            kind="damage_charge",
            summary=text,
            amount_paise=amount,
            booking_id=booking.id,
        )
    )
    return booking


async def charge_items(session: AsyncSession, booking: Booking) -> list[dict]:
    items = [
        {"label": "Late fee", "amount_paise": booking.late_fee_paise or 0},
        {"label": "Damage charge", "amount_paise": booking.damage_paise},
        {
            "label": "Extensions paid in cash",
            "amount_paise": await rental.unpaid_cash_extensions(session, booking),
        },
    ]
    return [item for item in items if item["amount_paise"] > 0]


async def pay_charges(
    session: AsyncSession,
    booking_id: uuid.UUID,
    renter: AccountContext,
    method: str,
    idempotency_key: str,
) -> PaymentView:
    booking = await get_booking(session, booking_id, renter, lock=True)
    require_party(booking, renter, "renter")
    require_status(booking, "returning")
    _require_item_back(booking)
    items = await charge_items(session, booking)
    total = sum(item["amount_paise"] for item in items)
    if total == 0:
        raise ApiError(409, "NOTHING_TO_PAY", "Nothing is owed")
    return await start_payment(
        booking.id,
        "return_charges",
        booking.renter_id,
        booking.owner_id,
        total,
        method,
        idempotency_key,
        items=items,
    )


async def charges_settled(session: AsyncSession, booking: Booking) -> bool:
    items = await charge_items(session, booking)
    if not items:
        return True
    paid = await payment_status(booking.id, "return_charges")
    return paid is not None and paid.is_paid


async def proceed(session: AsyncSession, booking_id: uuid.UUID, owner: AccountContext) -> Booking:
    """Closes the return once everything owed is paid. Reviews open."""
    booking = await get_booking(session, booking_id, owner, lock=True)
    require_party(booking, owner, "owner")
    require_status(booking, "returning")
    _require_item_back(booking)
    if not await charges_settled(session, booking):
        raise ApiError(409, "CHARGES_UNPAID", "The renter hasn't paid the charges yet")
    transition(
        session,
        booking,
        "awaiting_reviews",
        actor_id=owner.id,
        actor_role="owner",
        action="proceed",
    )
    booking.proceeded_at = booking.reviews_open_at = now()
    await cancel_timers(session, booking.id, timers.STALLED_PROCEED)
    emit(session, "ReviewPending", booking.id, payload(booking))
    return booking
