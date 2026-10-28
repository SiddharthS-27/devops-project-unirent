"""BookingOut: the booking screen's timeline, the one next action, and every
detail the app shows. Rules about who sees what are applied here."""

from dataclasses import dataclass, field

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import PaymentView, payments_for_booking
from unirent_payments.api import payment_out
from unirent_security import AccountContext

from app.core import storage
from app.core.clock import now
from app.core.pagination import decode_offset, encode_offset
from app.core.schemas import Page
from app.modules.bookings.models import Booking
from app.modules.bookings.schemas import (
    BookingOut,
    BookingSummary,
    NextAction,
    TimelineStep,
)
from app.modules.bookings.state import GROUPS
from app.modules.listings.models import Listing, ListingPhoto
from app.modules.listings.service import cards, current_late_fee_rule
from app.modules.profiles.service import profile_for_viewer, profiles_for

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
    photos: dict[tuple[str, str], list[str]] = field(default_factory=dict)

    def paid(self, purpose: str) -> PaymentView | None:
        return next(
            (p for p in self.payments if p.purpose == purpose and p.status != "failed"), None
        )

    def has_photos(self, phase: str, side: str) -> bool:
        return bool(self.photos.get((phase, side)))


async def load_facts(session: AsyncSession, booking: Booking) -> Facts:
    return Facts(payments=await payments_for_booking(booking.id))


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
    current = CURRENT_STEP[booking.status]
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


def _action(key: str, label: str, by_me: bool) -> NextAction:
    return NextAction(key=key, label=label, by_me=by_me)


def next_action(booking: Booking, role: str, facts: Facts) -> NextAction | None:
    """The one card the booking screen shows. `role` is renter, owner or staff."""
    if role == "staff":
        return None
    other = "owner" if role == "renter" else "renter"
    status = booking.status
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
    return None


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
        pickup=None,
        **{"return": None},
        payments=[payment_out(p) for p in facts.payments],
        extensions=[],
        charges=None,
        cancellation=None,
        appeal=None,
        reviews=None,
        overdue_since=booking.overdue_since,
        escalation_available_at=None,
        can_cancel=False,
        can_escalate=False,
        can_appeal=False,
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
