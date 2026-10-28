"""The booking lifecycle. Each operation locks the booking row, checks the actor,
moves the state machine, and writes the event to the outbox in one transaction."""

import uuid
from datetime import datetime, timedelta

from sqlalchemy import and_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import current_late_fee_rule, payment_status
from unirent_payments.late_fees import get_rule
from unirent_security import AccountContext, require_owner

from app.core.clock import now
from app.core.errors import ApiError, not_found
from app.core.outbox import emit
from app.core.timers import cancel_timers, schedule
from app.modules.bookings import pricing, timers
from app.modules.bookings.events import payload
from app.modules.bookings.models import HOLDS_SLOT, Booking, Cancellation, HandoverPhoto
from app.modules.bookings.state import record, require_status, transition
from app.modules.listings.models import Asset, AssetEvent, Listing
from app.modules.listings.service import get_listing
from app.modules.profiles.service import profiles_for
from app.modules.reviews.models import Review
from app.modules.trust import service as trust

REQUEST_TTL = timedelta(hours=24)
REMINDER_BEFORE = timedelta(hours=1)


async def get_booking(
    session: AsyncSession, booking_id: uuid.UUID, viewer: AccountContext, *, lock: bool = False
) -> Booking:
    """Only the renter, the owner and staff can see a booking; others get 404."""
    booking = await session.get(Booking, booking_id, with_for_update=lock)
    if booking is None:
        raise not_found("Booking")
    require_owner(viewer, booking.renter_id, booking.owner_id, what="Booking")
    return booking


def require_party(booking: Booking, actor: AccountContext, role: str) -> None:
    if booking.role_of(actor.id) != role:
        raise ApiError(
            403, "NOT_YOUR_STEP", f"Only the {'owner' if role == 'owner' else 'renter'} can do this"
        )


async def _slot_taken(session: AsyncSession, listing_id: uuid.UUID, start, end) -> bool:
    found = await session.scalar(
        select(Booking.id)
        .where(
            Booking.listing_id == listing_id,
            Booking.kind == "rent",
            Booking.status.in_(HOLDS_SLOT),
            Booking.start_at < end,
            Booking.end_at > start,
        )
        .limit(1)
    )
    return found is not None


async def request(
    session: AsyncSession,
    renter: AccountContext,
    listing_id: uuid.UUID,
    start_at: datetime | None,
    end_at: datetime | None,
) -> Booking:
    listing = await get_listing(session, listing_id)
    if listing.status != "active":
        raise ApiError(409, "LISTING_UNAVAILABLE", "This listing isn't available")
    if listing.owner_id == renter.id:
        raise ApiError(409, "OWN_LISTING", "You can't request your own listing")
    _, amount = pricing.quote(listing, start_at, end_at)

    open_request = await session.scalar(
        select(Booking.id).where(
            Booking.listing_id == listing.id,
            Booking.renter_id == renter.id,
            Booking.status.in_(("requested", "approved")),
        )
    )
    if open_request is not None:
        raise ApiError(409, "REQUEST_EXISTS", "You already have an open request for this")
    if listing.kind == "rent" and await _slot_taken(session, listing.id, start_at, end_at):
        raise ApiError(409, "SLOT_TAKEN", "Those dates are already booked")

    at = now()
    booking = Booking(
        id=uuid.uuid4(),
        listing_id=listing.id,
        asset_id=listing.asset_id,
        kind=listing.kind,
        status="requested",
        renter_id=renter.id,
        owner_id=listing.owner_id,
        start_at=start_at,
        end_at=end_at,
        amount_paise=amount,
        listing_title=listing.title,
        pickup_point=listing.pickup_point,
        created_at=at,
        updated_at=at,
    )
    session.add(booking)
    await session.flush()
    record(session, booking, renter.id, "renter", "request")
    requester = (await profiles_for(session, [renter.id])).get(renter.id)
    emit(
        session,
        "BookingRequested",
        booking.id,
        payload(
            booking,
            amount_paise=amount,
            requester_name=requester.full_name if requester else "A student",
        ),
    )
    schedule(session, timers.REQUEST_EXPIRY, booking.id, at + REQUEST_TTL)
    return booking


def _decided(session: AsyncSession, booking: Booking, decision: str, reason=None) -> None:
    emit(
        session,
        "BookingDecided",
        booking.id,
        payload(booking, decision=decision, reason=reason),
    )


async def _auto_decline_others(session: AsyncSession, booking: Booking) -> int:
    """On approval: pending requests that clash (all of them, for a sale) are declined."""
    clash = [Booking.listing_id == booking.listing_id, Booking.status == "requested"]
    clash.append(Booking.id != booking.id)
    if booking.kind == "rent":
        clash.append(and_(Booking.start_at < booking.end_at, Booking.end_at > booking.start_at))
    others = await session.scalars(select(Booking).where(*clash).with_for_update())
    count = 0
    for other in others:
        transition(
            session,
            other,
            "declined",
            actor_id=None,
            actor_role="system",
            action="auto_decline",
            details={"approved_booking": str(booking.id)},
        )
        other.decided_at = now()
        other.decline_reason = "Another request for these dates was approved"
        await cancel_timers(session, other.id)
        _decided(session, other, "auto_declined", other.decline_reason)
        count += 1
    return count


async def lock_terms(session: AsyncSession, booking: Booking, listing: Listing) -> None:
    """Price and terms freeze at approval: the owner may have updated the listed
    price after negotiating by phone."""
    if booking.kind == "rent":
        _, booking.amount_paise = pricing.quote_locked(listing, booking.start_at, booking.end_at)
    else:
        booking.amount_paise = listing.sale_price_paise or booking.amount_paise
    booking.listing_title = listing.title
    booking.pickup_point = listing.pickup_point
    if booking.kind == "rent":
        booking.late_fee_rule_id = (await current_late_fee_rule()).id


async def approve(session: AsyncSession, booking_id: uuid.UUID, owner: AccountContext) -> Booking:
    booking = await get_booking(session, booking_id, owner, lock=True)
    require_party(booking, owner, "owner")
    require_status(booking, "requested")
    listing = await get_listing(session, booking.listing_id, lock=True)
    if listing.status != "active":
        raise ApiError(409, "LISTING_UNAVAILABLE", "Resume the listing before approving")
    await lock_terms(session, booking, listing)
    transition(
        session, booking, "approved", actor_id=owner.id, actor_role="owner", action="approve"
    )
    booking.decided_at = now()
    try:
        await session.flush()
    except IntegrityError:
        await session.rollback()
        raise ApiError(
            409, "SLOT_TAKEN", "You already approved a booking for these dates"
        ) from None
    await _auto_decline_others(session, booking)
    await cancel_timers(session, booking.id, timers.REQUEST_EXPIRY)
    if booking.start_at and booking.start_at - REMINDER_BEFORE > now():
        schedule(session, timers.PICKUP_REMINDER, booking.id, booking.start_at - REMINDER_BEFORE)
    _decided(session, booking, "approved")
    return booking


async def decline(
    session: AsyncSession, booking_id: uuid.UUID, owner: AccountContext, reason: str | None
) -> Booking:
    booking = await get_booking(session, booking_id, owner, lock=True)
    require_party(booking, owner, "owner")
    require_status(booking, "requested")
    transition(
        session, booking, "declined", actor_id=owner.id, actor_role="owner", action="decline"
    )
    booking.decided_at = now()
    booking.decline_reason = reason
    await cancel_timers(session, booking.id)
    _decided(session, booking, "declined", reason)
    return booking


async def withdraw(session: AsyncSession, booking_id: uuid.UUID, renter: AccountContext) -> Booking:
    booking = await get_booking(session, booking_id, renter, lock=True)
    require_party(booking, renter, "renter")
    require_status(booking, "requested")
    transition(
        session, booking, "withdrawn", actor_id=renter.id, actor_role="renter", action="withdraw"
    )
    await cancel_timers(session, booking.id)
    emit(session, "BookingWithdrawn", booking.id, payload(booking))
    return booking


async def expire(session: AsyncSession, booking: Booking) -> bool:
    """The 24-hour timer: an unanswered request expires. False if already answered."""
    if booking.status != "requested":
        return False
    transition(session, booking, "expired", actor_id=None, actor_role="system", action="expire")
    _decided(session, booking, "expired")
    return True


async def cancel(
    session: AsyncSession, booking_id: uuid.UUID, actor: AccountContext, note: str
) -> Booking:
    """Either side, after approval and until the pickup payment and OTP. The note
    goes to the other side, who then rates the canceller."""
    booking = await get_booking(session, booking_id, actor, lock=True)
    role = booking.role_of(actor.id)
    if role is None:
        raise ApiError(403, "NOT_YOUR_STEP", "Only the two sides can cancel")
    require_status(booking, "approved")
    purpose = "rent" if booking.kind == "rent" else "sale"
    paid = await payment_status(booking.id, purpose)
    if paid is not None and paid.is_paid:
        raise ApiError(409, "ALREADY_PAID", "It's paid for; finish the handover or ask for help")
    transition(session, booking, "cancelled", actor_id=actor.id, actor_role=role, action="cancel")
    session.add(
        Cancellation(booking_id=booking.id, by_id=actor.id, by_role=role, note=note, at=now())
    )
    await cancel_timers(session, booking.id)
    emit(session, "BookingCancelled", booking.id, payload(booking, cancelled_by=role, note=note))
    await session.flush()
    await trust.recompute(session, actor.id)
    return booking


async def rate_cancellation(
    session: AsyncSession, booking_id: uuid.UUID, actor: AccountContext, stars: int, comment: str
) -> Booking:
    booking = await get_booking(session, booking_id, actor)
    cancellation = await session.get(Cancellation, booking.id, with_for_update=True)
    if cancellation is None:
        raise ApiError(409, "NOT_CANCELLED", "This booking wasn't cancelled")
    if booking.role_of(actor.id) in (None, cancellation.by_role):
        raise ApiError(403, "NOT_YOUR_STEP", "The other side rates the cancellation")
    if cancellation.rated_at is not None:
        raise ApiError(409, "ALREADY_RATED", "You already rated this cancellation")
    cancellation.rating_stars = stars
    cancellation.rating_comment = comment
    cancellation.rated_at = now()
    session.add(
        Review(
            id=uuid.uuid4(),
            booking_id=booking.id,
            reviewer_id=actor.id,
            reviewee_id=cancellation.by_id,
            review_type="cancellation",
            # Counts toward the canceller's rating in the role they cancelled from.
            reviewee_role="renter" if cancellation.by_role == "renter" else "lender",
            ratings={"overall": stars},
            overall=stars,
            comment=comment,
            created_at=now(),
            revealed_at=now(),
        )
    )
    await session.flush()
    await trust.recompute(session, cancellation.by_id)
    record(session, booking, actor.id, booking.role_of(actor.id) or "", "rate_cancellation")
    return booking


async def complete_pickup(session: AsyncSession, booking: Booking, actor: AccountContext) -> None:
    """The owner typed the right code: a rental becomes active; a sale moves to reviews."""
    at = now()
    booking.pickup_completed_at = at
    if booking.kind == "rent":
        transition(
            session, booking, "active", actor_id=actor.id, actor_role="owner", action="pickup"
        )
        asset = await session.get(Asset, booking.asset_id, with_for_update=True)
        asset.rental_count += 1  # type: ignore[union-attr]
        session.add(
            AssetEvent(
                id=uuid.uuid4(),
                asset_id=booking.asset_id,
                at=at,
                kind="rented",
                summary="Rented out",
                booking_id=booking.id,
                photo_keys=await _phase_keys(session, booking.id, "pickup"),
            )
        )
        await cancel_timers(session, booking.id, timers.PICKUP_REMINDER)
        if booking.end_at and booking.end_at - REMINDER_BEFORE > at:
            schedule(session, timers.RETURN_REMINDER, booking.id, booking.end_at - REMINDER_BEFORE)
        rule = await get_rule(booking.late_fee_rule_id) if booking.late_fee_rule_id else None
        grace = timedelta(minutes=rule.grace_minutes if rule else 0)
        schedule(session, timers.OVERDUE_START, booking.id, booking.end_at + grace)  # type: ignore[operator]
    else:
        transition(
            session,
            booking,
            "awaiting_reviews",
            actor_id=actor.id,
            actor_role="owner",
            action="handover",
        )
        await transfer_asset(session, booking)
    emit(session, "PickupCompleted", booking.id, payload(booking))


async def _phase_keys(session: AsyncSession, booking_id: uuid.UUID, phase: str) -> list[str]:
    rows = await session.scalars(
        select(HandoverPhoto.object_key).where(
            HandoverPhoto.booking_id == booking_id, HandoverPhoto.phase == phase
        )
    )
    return list(rows)


SALE_APPEAL_WINDOW = timedelta(hours=48)


async def transfer_asset(session: AsyncSession, booking: Booking) -> None:
    """A sale's handover: the listing is sold and the asset, with its whole history,
    now belongs to the buyer, who can relist it. The buyer may appeal for 48 hours."""
    listing = await session.get(Listing, booking.listing_id, with_for_update=True)
    asset = await session.get(Asset, booking.asset_id, with_for_update=True)
    listing.status = "sold"  # type: ignore[union-attr]
    listing.updated_at = now()  # type: ignore[union-attr]
    asset.owner_id = booking.renter_id  # type: ignore[union-attr]
    session.add(
        AssetEvent(
            id=uuid.uuid4(),
            asset_id=booking.asset_id,
            at=now(),
            kind="sold",
            summary="Sold to a new owner",
            amount_paise=booking.amount_paise,
            booking_id=booking.id,
            photo_keys=await _phase_keys(session, booking.id, "pickup"),
        )
    )
    booking.appeal_window_until = now() + SALE_APPEAL_WINDOW
    schedule(session, timers.SALE_APPEAL_CLOSE, booking.id, booking.appeal_window_until)
