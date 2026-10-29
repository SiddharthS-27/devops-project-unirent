"""Appeals and rulings. Disputes are settled between the students first; a
moderator steps in only on appeal, and the admin can overrule any ruling."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import issue_refund, payment_status
from unirent_security import AccountContext, audit, set_account_status, staff_ids

from app.core import storage
from app.core.clock import now
from app.core.errors import ApiError, not_found
from app.core.outbox import emit
from app.modules.bookings.events import payload
from app.modules.bookings.models import Booking
from app.modules.bookings.service import get_booking
from app.modules.bookings.state import record, transition
from app.modules.listings.models import Listing
from app.modules.moderation.models import Appeal, Ruling, TrustPenalty
from app.modules.staff.schemas import RulingIn
from app.modules.trust import service as trust


def can_file(booking: Booking, role: str | None) -> bool:
    if role is None:
        return False
    if booking.kind == "rent":
        return booking.status == "returning" and booking.return_completed_at is not None
    window = booking.appeal_window_until
    return (
        role == "renter"
        and booking.status in ("awaiting_reviews", "completed")
        and window is not None
        and now() < window
    )


async def file(
    session: AsyncSession,
    booking_id: uuid.UUID,
    actor: AccountContext,
    reason: str,
    notes: str,
    photo_keys: list[str],
) -> Appeal:
    """Either side of a return dispute, or the buyer within 48 hours of a sale."""
    booking = await get_booking(session, booking_id, actor, lock=True)
    role = booking.role_of(actor.id)
    if role is None:
        raise ApiError(403, "NOT_YOUR_STEP", "Only the two sides can appeal")
    if not can_file(booking, role):
        raise ApiError(409, "APPEAL_NOT_OPEN", "This booking can't be appealed now")
    for key in photo_keys:
        await storage.confirm_upload(key, "appeal", actor.id)
    appeal = Appeal(
        id=uuid.uuid4(),
        booking_id=booking.id,
        filed_by_id=actor.id,
        filed_by_role=role,
        reason=reason,
        notes=notes,
        photo_keys=photo_keys,
        previous_status=booking.status,
        status="open",
        created_at=now(),
    )
    session.add(appeal)
    transition(session, booking, "in_appeal", actor_id=actor.id, actor_role=role, action="appeal")
    moderators = [str(m) for m in await staff_ids()]
    emit(
        session,
        "AppealFiled",
        booking.id,
        payload(booking, appeal_id=str(appeal.id), filed_by=role, moderator_ids=moderators),
    )
    return appeal


async def get_appeal(session: AsyncSession, appeal_id: uuid.UUID, *, lock=False) -> Appeal:
    appeal = await session.get(Appeal, appeal_id, with_for_update=lock)
    if appeal is None:
        raise not_found("Appeal")
    return appeal


async def _locked_booking(session: AsyncSession, appeal: Appeal) -> Booking:
    booking = await session.get(Booking, appeal.booking_id, with_for_update=True)
    if booking is None:
        raise not_found("Booking")
    return booking


async def _refundable_payment(booking: Booking):
    """The ruling refunds from the return charges first, then the rent or sale price."""
    purposes = ["return_charges", "rent"] if booking.kind == "rent" else ["sale"]
    for purpose in purposes:
        payment = await payment_status(booking.id, purpose)
        if payment is not None and payment.is_paid:
            left = payment.amount_paise - payment.refunded_paise
            if left > 0:
                return payment, left
    return None, 0


async def _apply(
    session: AsyncSession,
    booking: Booking,
    ruling: Ruling,
    body: RulingIn,
    staff: AccountContext,
) -> None:
    if body.charge_paise is not None and booking.kind == "rent" and booking.proceeded_at is None:
        booking.damage_paise = body.charge_paise
        booking.damage_description = body.summary
    if body.refund_paise:
        payment, left = await _refundable_payment(booking)
        if payment is None or body.refund_paise > left:
            raise ApiError(422, "REFUND_TOO_LARGE", "There isn't that much paid to refund")
        refund = await issue_refund(payment.id, body.refund_paise, ruling.id, by=staff.id)
        ruling.refund_id = refund.id
    if body.trust_penalty:
        p = body.trust_penalty
        session.add(
            TrustPenalty(
                id=uuid.uuid4(),
                account_id=p.account_id,
                role=p.role,
                points=p.points,
                reason=body.summary,
                by=staff.id,
                ruling_id=ruling.id,
                created_at=now(),
            )
        )
    if body.remove_listing:
        listing = await session.get(Listing, booking.listing_id, with_for_update=True)
        if listing is not None and listing.status in ("active", "paused"):
            listing.status = "removed"
            listing.removed_reason = body.summary
    if body.account_action:
        action = body.account_action
        await set_account_status(action.account_id, action.status, staff.id, body.summary, session)
        emit(
            session,
            "AccountStatusChanged",
            action.account_id,
            {"account_id": str(action.account_id), "status": action.status, "reason": body.summary},
        )
    await session.flush()
    affected = [booking.renter_id, booking.owner_id]
    if body.trust_penalty:
        affected.append(body.trust_penalty.account_id)
    await trust.recompute(session, *affected)


def _parties_only(body: RulingIn, booking: Booking) -> None:
    parties = {booking.renter_id, booking.owner_id}
    for target in (body.trust_penalty, body.account_action):
        if target is not None and target.account_id not in parties:
            raise ApiError(422, "NOT_A_PARTY", "Rulings apply to the two sides of this booking")


async def rule(
    session: AsyncSession, appeal_id: uuid.UUID, staff: AccountContext, body: RulingIn
) -> Appeal:
    appeal = await get_appeal(session, appeal_id, lock=True)
    if appeal.status != "open":
        raise ApiError(409, "APPEAL_RULED", "This appeal already has a ruling")
    booking = await _locked_booking(session, appeal)
    _parties_only(body, booking)
    ruling = Ruling(
        id=uuid.uuid4(),
        appeal_id=appeal.id,
        ruled_by=staff.id,
        summary=body.summary,
        charge_paise=body.charge_paise,
        refund_paise=body.refund_paise,
        trust_penalty=body.trust_penalty.model_dump(mode="json") if body.trust_penalty else None,
        remove_listing=body.remove_listing,
        account_action=body.account_action.model_dump(mode="json") if body.account_action else None,
        ruled_at=now(),
    )
    session.add(ruling)
    await session.flush()
    await _apply(session, booking, ruling, body, staff)
    appeal.status = "ruled"
    back_to = "returning" if booking.kind == "rent" else appeal.previous_status
    transition(session, booking, back_to, actor_id=staff.id, actor_role="staff", action="ruling")
    emit(
        session,
        "AppealRuled",
        booking.id,
        payload(booking, appeal_id=str(appeal.id), summary=body.summary),
    )
    await audit.record(
        staff,
        "moderation.ruling",
        audit.target("appeal", appeal.id),
        body.model_dump(mode="json"),
        session=session,
    )
    return appeal


async def _undo(
    session: AsyncSession, booking: Booking, ruling: Ruling, admin: AccountContext
) -> None:
    """Reverse what can be reversed. A refund already paid out stays paid."""
    if ruling is None:
        return
    penalties = await session.scalars(
        select(TrustPenalty).where(
            TrustPenalty.ruling_id == ruling.id, TrustPenalty.revoked_at.is_(None)
        )
    )
    for penalty in penalties:
        penalty.revoked_at = now()
    if ruling.account_action:
        account_id = uuid.UUID(ruling.account_action["account_id"])
        await set_account_status(account_id, "active", admin.id, "ruling overruled", session)
        emit(
            session,
            "AccountStatusChanged",
            account_id,
            {"account_id": str(account_id), "status": "active", "reason": "Ruling overruled"},
        )
    if ruling.remove_listing:
        listing = await session.get(Listing, booking.listing_id, with_for_update=True)
        if listing is not None and listing.status == "removed":
            listing.status = "paused"  # the owner decides whether to show it again
            listing.removed_reason = None


async def overrule(
    session: AsyncSession, appeal_id: uuid.UUID, admin: AccountContext, body: RulingIn
) -> Appeal:
    appeal = await get_appeal(session, appeal_id, lock=True)
    if appeal.status == "open":
        raise ApiError(409, "APPEAL_OPEN", "There is no ruling to overrule yet")
    booking = await _locked_booking(session, appeal)
    _parties_only(body, booking)
    previous = await session.scalar(
        select(Ruling)
        .where(Ruling.appeal_id == appeal.id)
        .order_by(Ruling.ruled_at.desc())
        .limit(1)
    )
    await _undo(session, booking, previous, admin)
    ruling = Ruling(
        id=uuid.uuid4(),
        appeal_id=appeal.id,
        ruled_by=admin.id,
        summary=body.summary,
        charge_paise=body.charge_paise,
        refund_paise=body.refund_paise,
        trust_penalty=body.trust_penalty.model_dump(mode="json") if body.trust_penalty else None,
        remove_listing=body.remove_listing,
        account_action=body.account_action.model_dump(mode="json") if body.account_action else None,
        overrules=previous.id if previous else None,
        ruled_at=now(),
    )
    session.add(ruling)
    await session.flush()
    await _apply(session, booking, ruling, body, admin)
    appeal.status = "overruled"
    record(session, booking, admin.id, "staff", "overrule")
    emit(
        session,
        "RulingOverruled",
        booking.id,
        payload(booking, appeal_id=str(appeal.id), summary=body.summary),
    )
    await audit.record(
        admin,
        "admin.overrule",
        audit.target("appeal", appeal.id),
        body.model_dump(mode="json"),
        session=session,
    )
    return appeal


async def rulings_of(session: AsyncSession, appeal_id: uuid.UUID) -> list[Ruling]:
    rows = await session.scalars(
        select(Ruling).where(Ruling.appeal_id == appeal_id).order_by(Ruling.ruled_at)
    )
    return list(rows)
