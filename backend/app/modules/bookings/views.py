"""BookingOut: the booking screen's timeline, the one next action, and every
detail the app shows. Rules about who sees what are applied here."""

from dataclasses import dataclass, field

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import PaymentView, payment_status, payments_for_booking
from unirent_payments.api import payment_out
from unirent_security import AccountContext

from app.core import storage
from app.core.clock import now
from app.core.pagination import decode_offset, encode_offset
from app.core.schemas import Page, PhotoOut
from app.modules.bookings import rental
from app.modules.bookings.handover import SHOWS_CODE, photo_keys
from app.modules.bookings.models import Booking, Cancellation, Extension
from app.modules.bookings.schemas import (
    AppealOut,
    AppealRef,
    BookingOut,
    BookingSummary,
    CancellationInfo,
    Charges,
    ExtensionOut,
    Handover,
    HandoverSide,
    NextAction,
    ReviewState,
    TimelineStep,
)
from app.modules.bookings.state import GROUPS
from app.modules.listings.models import Listing, ListingPhoto
from app.modules.listings.service import cards, current_late_fee_rule
from app.modules.moderation.appeals import can_file
from app.modules.moderation.models import Appeal
from app.modules.profiles.service import profile_for_viewer, profiles_for
from app.modules.reviews.models import Review
from app.modules.reviews.service import RELEASE_AFTER, reviews_of

RENT_STEPS = [
    ("requested", "Requested"),
    ("approved", "Approved"),
    ("pickup", "Pickup"),
    ("active", "Rental active"),
    ("return", "Return"),
    ("proceed", "Charges and Proceed"),
    ("reviews", "Reviews"),
    ("completed", "Completed"),
]
SALE_STEPS = [
    ("requested", "Requested"),
    ("approved", "Approved"),
    ("pickup", "Handover"),
    ("reviews", "Reviews"),
    ("completed", "Completed"),
]
# Which step is current in each status.
CURRENT_STEP = {
    "requested": "requested",
    "approved": "pickup",
    "active": "active",
    "overdue": "active",
    "returning": "return",
    "in_appeal": "proceed",
    "awaiting_reviews": "reviews",
    "completed": "completed",
}
# A sale has no charges step: an appeal after the handover sits at Reviews.
SALE_CURRENT_STEP = {**CURRENT_STEP, "in_appeal": "reviews"}
ENDED = {
    "declined": "Declined",
    "withdrawn": "Withdrawn",
    "expired": "Expired",
    "cancelled": "Cancelled",
}


@dataclass
class Facts:
    """What the next action depends on, loaded once per booking."""

    payments: list[PaymentView] = field(default_factory=list)
    cancellation: Cancellation | None = None
    extensions: list[Extension] = field(default_factory=list)
    late_fee_paise: int = 0
    cash_extensions_paise: int = 0
    reviews: list[Review] = field(default_factory=list)
    appeal: Appeal | None = None
    photos: dict[tuple[str, str], list[str]] = field(default_factory=dict)

    def paid(self, purpose: str) -> PaymentView | None:
        return next(
            (p for p in self.payments if p.purpose == purpose and p.status != "failed"), None
        )

    def paid_ref(self, purpose: str, ref) -> PaymentView | None:
        return next(
            (
                p
                for p in self.payments
                if p.purpose == purpose and p.purpose_ref == ref and p.status != "failed"
            ),
            None,
        )

    def has_photos(self, phase: str, side: str) -> bool:
        return bool(self.photos.get((phase, side)))


async def load_facts(session: AsyncSession, booking: Booking) -> Facts:
    facts = Facts(
        payments=await payments_for_booking(booking.id),
        photos=await photo_keys(session, booking.id),
    )
    if booking.status == "cancelled":
        facts.cancellation = await session.get(Cancellation, booking.id)
    facts.appeal = await session.scalar(
        select(Appeal).where(Appeal.booking_id == booking.id).order_by(Appeal.created_at.desc())
    )
    if booking.status in ("awaiting_reviews", "completed", "in_appeal"):
        facts.reviews = list(
            await session.scalars(select(Review).where(Review.booking_id == booking.id))
        )
    if booking.kind == "rent" and booking.pickup_completed_at is not None:
        facts.extensions = list(
            await session.scalars(
                select(Extension)
                .where(Extension.booking_id == booking.id)
                .order_by(Extension.created_at)
            )
        )
        facts.late_fee_paise = await rental.live_late_fee(booking)
        facts.cash_extensions_paise = await rental.unpaid_cash_extensions(session, booking)
    return facts


def timeline(booking: Booking) -> list[TimelineStep]:
    steps = RENT_STEPS if booking.kind == "rent" else SALE_STEPS
    if booking.status in ENDED:
        reached = "requested" if booking.status != "cancelled" else "approved"
        out = []
        for key, label in steps:
            out.append(TimelineStep(key=key, label=label, state="done"))
            if key == reached:
                break
        out.append(
            TimelineStep(
                key=booking.status,
                label=ENDED[booking.status],
                state="current",
                at=booking.updated_at,
            )
        )
        return out
    current = (CURRENT_STEP if booking.kind == "rent" else SALE_CURRENT_STEP)[booking.status]
    keys = [k for k, _ in steps]
    index = keys.index(current)
    if booking.status == "completed":
        index = len(keys)
    stamps = {
        "requested": booking.created_at,
        "approved": booking.decided_at,
        "pickup": booking.pickup_completed_at,
        "return": booking.return_completed_at,
        "proceed": booking.proceeded_at,
        "completed": booking.completed_at,
    }
    return [
        TimelineStep(
            key=key,
            label=label,
            state="done" if i < index else "current" if i == index else "upcoming",
            at=stamps.get(key) if i < index else None,
        )
        for i, (key, label) in enumerate(steps)
    ]


def _handover(booking: Booking, facts: Facts, phase: str) -> Handover | None:
    if phase == "pickup" and booking.status in ("requested", "declined", "withdrawn", "expired"):
        return None
    if phase == "return" and booking.return_started_at is None:
        return None

    def side(name: str) -> HandoverSide:
        keys = facts.photos.get((phase, name), [])
        return HandoverSide(
            photos=[PhotoOut(id=k, url=storage.photo_url(k) or "") for k in keys], done=bool(keys)
        )

    renter, owner = side("renter"), side("owner")
    if phase == "pickup":
        payment = facts.paid("rent" if booking.kind == "rent" else "sale")
        ready = renter.done and owner.done and payment is not None and payment.is_paid
        verified = booking.pickup_completed_at
    else:
        ready = renter.done and owner.done
        verified = booking.return_completed_at
    return Handover(
        phase=phase,  # type: ignore[arg-type]
        renter=renter,
        owner=owner,
        otp_ready=ready and verified is None,
        otp_shown_by=SHOWS_CODE[phase],  # type: ignore[arg-type]
        otp_verified_at=verified,
    )


def _charges(booking: Booking, facts: Facts) -> Charges | None:
    """What the renter owes at return. Shown once anything is owed or the item is back."""
    if booking.kind != "rent" or booking.pickup_completed_at is None:
        return None
    total = facts.late_fee_paise + booking.damage_paise + facts.cash_extensions_paise
    if total == 0 and booking.return_started_at is None:
        return None
    payment = facts.paid("return_charges")
    return Charges(
        late_fee_paise=facts.late_fee_paise,
        overdue_minutes=rental.overdue_minutes(booking) if booking.late_fee_paise is None else 0,
        damage_paise=booking.damage_paise,
        damage_description=booking.damage_description,
        cash_extensions_paise=facts.cash_extensions_paise,
        total_paise=total,
        paid=total == 0 or (payment is not None and payment.is_paid),
        payment=payment_out(payment) if payment else None,
    )


def _cancellation(facts: Facts, role: str) -> CancellationInfo | None:
    c = facts.cancellation
    if c is None:
        return None
    return CancellationInfo(
        by=c.by_role,  # type: ignore[arg-type]
        note=c.note,
        at=c.at,
        rating_due=c.by_role != role and role != "staff" and c.rated_at is None,
    )


def _action(key: str, label: str, by_me: bool) -> NextAction:
    return NextAction(key=key, label=label, by_me=by_me)


def next_action(booking: Booking, role: str, facts: Facts) -> NextAction | None:
    """The one card the booking screen shows. `role` is renter, owner or staff."""
    if role == "staff":
        return None
    other = "owner" if role == "renter" else "renter"
    status = booking.status
    if status == "cancelled":
        c = facts.cancellation
        if c is not None and c.by_role != role and c.rated_at is None:
            return _action("rate_cancellation", "Read the reason and rate the cancellation", True)
        return None
    if status == "requested":
        if role == "owner":
            return _action("decide_request", "Approve or decline the request", True)
        return _action("waiting_owner", "Waiting for the owner", False)
    if status == "approved":
        if not facts.has_photos("pickup", role):
            return _action("upload_pickup_photos", "Upload pickup photos", True)
        if not facts.has_photos("pickup", other):
            return _action("waiting_pickup_photos", "Waiting for their photos", False)
        purpose = "rent" if booking.kind == "rent" else "sale"
        payment = facts.paid(purpose)
        if payment is None or not payment.is_paid:
            if role == "renter":
                if payment and payment.method == "cash":
                    return _action("waiting_cash_mark", "Waiting for cash to be marked", False)
                return _action("pay", "Pay by UPI or cash", True)
            if payment and payment.method == "cash":
                return _action("mark_cash_received", "Mark cash received", True)
            return _action("waiting_payment", "Waiting for payment", False)
        if role == "renter":
            return _action("show_otp", "Show your code to the owner", True)
        return _action("enter_otp", "Enter the renter's code", True)
    pending = next((e for e in facts.extensions if e.status == "requested"), None)
    if status == "active":
        if pending is not None:
            if role == "owner":
                return _action("decide_extension", "Approve or decline more time", True)
            return _action("waiting_extension", "Waiting for the owner about more time", False)
        unpaid = next(
            (
                e
                for e in facts.extensions
                if e.status == "approved"
                and not e.pay_in_cash_at_return
                and not (facts.paid_ref("extension", e.id) or _NotPaid).is_paid
            ),
            None,
        )
        if unpaid is not None and role == "renter":
            return _action("pay_extension", "Pay for the extra time", True)
        if role == "renter":
            return _action("return_on_time", "Return the item on time", False)
        return _action("rental_active", "Rental in progress", False)
    if status == "returning":
        return _return_action(booking, role, facts)
    if status == "in_appeal":
        return _action("waiting_ruling", "A moderator is looking at the appeal", False)
    if status == "awaiting_reviews":
        me = booking.renter_id if role == "renter" else booking.owner_id
        if not any(r.reviewer_id == me for r in facts.reviews):
            return _action("write_review", "Review the other side to continue", True)
        return _action("waiting_review", "Waiting for their review", False)
    if status == "overdue":
        if role == "renter":
            return _action("return_now", "Overdue: return the item now", True)
        if booking.escalated_at is None and _can_escalate(booking):
            return _action("escalate", "You can escalate to the moderators", True)
        return _action("waiting_return", "Waiting for the return", False)
    return None


def _return_action(booking: Booking, role: str, facts: Facts) -> NextAction:
    renter_done = facts.has_photos("return", "renter")
    owner_done = facts.has_photos("return", "owner")
    if not renter_done:
        if role == "renter":
            return _action("upload_return_photos", "Upload return photos", True)
        return _action("waiting_return_photos", "Waiting for the renter's photos", False)
    if not owner_done:
        if role == "owner":
            return _action("inspect_item", "Inspect the item and upload photos", True)
        return _action("waiting_inspection", "The owner is inspecting the item", False)
    if booking.return_completed_at is None:
        if role == "owner":
            return _action("show_return_otp", "Show your code to the renter", True)
        return _action("enter_return_otp", "Enter the owner's code", True)
    charges = _charges(booking, facts)
    if charges is not None and not charges.paid:
        if role == "renter":
            if charges.payment and charges.payment.method == "cash":
                return _action("waiting_cash_mark", "Waiting for cash to be marked", False)
            return _action("pay_charges", "Pay the charges", True)
        if charges.payment and charges.payment.method == "cash":
            return _action("mark_cash_received", "Mark cash received", True)
        return _action("record_damage_or_wait", "Record any damage, or wait for payment", True)
    if role == "owner":
        return _action("proceed", "Tap Proceed to finish", True)
    return _action("waiting_proceed", "Waiting for the owner to finish", False)


class _NotPaid:
    is_paid = False


def _can_escalate(booking: Booking) -> bool:
    available = rental.escalation_available_at(booking)
    return booking.status == "overdue" and available is not None and now() >= available


async def booking_out(
    session: AsyncSession, booking: Booking, viewer: AccountContext
) -> BookingOut:
    role = booking.role_of(viewer.id) or "staff"
    facts = await load_facts(session, booking)
    listing = await session.get(Listing, booking.listing_id)
    card = (await cards(session, [listing]))[0]  # type: ignore[list-item]
    rule = await current_late_fee_rule() if booking.kind == "rent" else None
    return BookingOut(
        id=booking.id,
        kind=booking.kind,  # type: ignore[arg-type]
        status=booking.status,  # type: ignore[arg-type]
        role=role,  # type: ignore[arg-type]
        listing=card,
        renter=await profile_for_viewer(session, viewer, booking.renter_id),
        owner=await profile_for_viewer(session, viewer, booking.owner_id),
        start_at=booking.start_at,
        end_at=booking.end_at,
        amount_paise=booking.amount_paise,
        late_fee_rule=rule,
        timeline=timeline(booking),
        next_action=next_action(booking, role, facts),
        pickup=_handover(booking, facts, "pickup"),
        **{"return": _handover(booking, facts, "return")},
        payments=[payment_out(p) for p in facts.payments],
        extensions=[await extension_out(e) for e in facts.extensions],
        charges=_charges(booking, facts),
        cancellation=_cancellation(facts, role),
        appeal=AppealRef(id=facts.appeal.id, status=facts.appeal.status)  # type: ignore[arg-type]
        if facts.appeal
        else None,
        reviews=_review_state(booking, viewer, facts.reviews),
        overdue_since=booking.overdue_since,
        escalation_available_at=rental.escalation_available_at(booking),
        can_cancel=booking.status == "approved"
        and role in ("renter", "owner")
        and not any(p.is_paid for p in facts.payments if p.purpose in ("rent", "sale")),
        can_escalate=role == "owner" and booking.escalated_at is None and _can_escalate(booking),
        can_appeal=can_file(booking, booking.role_of(viewer.id))
        and (facts.appeal is None or facts.appeal.status != "open"),
        server_now=now(),
        created_at=booking.created_at,
    )


async def summaries(
    session: AsyncSession,
    viewer: AccountContext,
    *,
    role: str,
    group: str | None,
    listing_id,
    cursor: str | None,
    limit: int,
) -> Page[BookingSummary]:
    column = Booking.renter_id if role == "renter" else Booking.owner_id
    stmt = select(Booking).where(column == viewer.id)
    if group:
        stmt = stmt.where(Booking.status.in_(GROUPS[group]))
    if listing_id:
        stmt = stmt.where(Booking.listing_id == listing_id)
    offset = decode_offset(cursor)
    rows = list(
        await session.scalars(
            stmt.order_by(Booking.updated_at.desc(), Booking.id).offset(offset).limit(limit + 1)
        )
    )
    page = rows[:limit]
    others = await profiles_for(
        session, [b.owner_id if role == "renter" else b.renter_id for b in page]
    )
    first_photos = await _first_photos(session, [b.listing_id for b in page])
    items = []
    for booking in page:
        other_id = booking.owner_id if role == "renter" else booking.renter_id
        other = others.get(other_id)
        facts = await load_facts(session, booking)
        items.append(
            BookingSummary(
                id=booking.id,
                kind=booking.kind,  # type: ignore[arg-type]
                status=booking.status,  # type: ignore[arg-type]
                role=role,  # type: ignore[arg-type]
                listing_id=booking.listing_id,
                listing_title=booking.listing_title,
                listing_photo_url=storage.photo_url(first_photos.get(booking.listing_id)),
                counterparty_id=other_id,
                counterparty_name=other.full_name if other else "UniRent user",
                start_at=booking.start_at,
                end_at=booking.end_at,
                amount_paise=booking.amount_paise,
                next_action=next_action(booking, role, facts),
                updated_at=booking.updated_at,
            )
        )
    return Page[BookingSummary](
        items=items, next_cursor=encode_offset(offset + limit) if len(rows) > limit else None
    )


async def _first_photos(session: AsyncSession, listing_ids) -> dict:
    rows = await session.execute(
        select(ListingPhoto.listing_id, func.min(ListingPhoto.object_key))
        .where(ListingPhoto.listing_id.in_(listing_ids), ListingPhoto.position == 0)
        .group_by(ListingPhoto.listing_id)
    )
    return dict(rows.all())


async def extension_out(extension: Extension) -> ExtensionOut:
    payment = await payment_status(extension.booking_id, "extension", extension.id)
    return ExtensionOut(
        id=extension.id,
        new_end_at=extension.new_end_at,
        status=extension.status,  # type: ignore[arg-type]
        amount_paise=extension.amount_paise,
        payment=payment_out(payment) if payment else None,
        pay_in_cash_at_return=extension.pay_in_cash_at_return,
        created_at=extension.created_at,
    )


async def review_state(session: AsyncSession, booking: Booking, viewer: AccountContext):
    return _review_state(booking, viewer, await reviews_of(session, booking.id))


def _review_state(
    booking: Booking, viewer: AccountContext, reviews: list[Review]
) -> ReviewState | None:
    if booking.status not in ("awaiting_reviews", "completed", "in_appeal"):
        return None
    mine = any(r.reviewer_id == viewer.id for r in reviews)
    theirs = any(r.reviewer_id != viewer.id for r in reviews)
    first = min((r.created_at for r in reviews), default=None)
    return ReviewState(
        mine_submitted=mine,
        theirs_submitted=theirs,
        revealed=any(r.revealed_at is not None for r in reviews),
        release_at=first + RELEASE_AFTER
        if first and booking.status == "awaiting_reviews"
        else None,
    )


def appeal_out(appeal: Appeal) -> AppealOut:
    return AppealOut(
        id=appeal.id,
        booking_id=appeal.booking_id,
        status=appeal.status,  # type: ignore[arg-type]
        reason=appeal.reason,
        notes=appeal.notes,
        filed_by=appeal.filed_by_role,  # type: ignore[arg-type]
        created_at=appeal.created_at,
    )
