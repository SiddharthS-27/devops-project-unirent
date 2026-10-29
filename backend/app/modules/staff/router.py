import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response
from sqlalchemy import select
from unirent_security import AdminAccount, StaffAccount

from app.core import storage
from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.schemas import Page, PhotoOut
from app.modules.bookings import views
from app.modules.bookings.handover import photo_keys
from app.modules.bookings.models import Booking
from app.modules.help.schemas import (
    SupportMessage,
    SupportMessageIn,
    SupportThreadOut,
    SupportThreadSummary,
)
from app.modules.listings.schemas import ListingCard, ListingStatus
from app.modules.moderation import appeals
from app.modules.moderation.models import Appeal
from app.modules.profiles.service import profiles_for
from app.modules.staff.schemas import (
    AppealDetail,
    AppealSummary,
    EscalationOut,
    PenaltyIn,
    ReasonIn,
    RulingIn,
    RulingOut,
    StaffUserDetail,
    StaffUserRow,
    StatusChangeIn,
)

router = APIRouter(prefix="/staff", tags=["staff"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/appeals", response_model=list[AppealSummary])
async def appeals_queue(
    staff: StaffAccount, session: SessionDep, status: Literal["open", "ruled", "all"] = "open"
):
    """Oldest open appeal first."""
    stmt = select(Appeal, Booking).join(Booking, Booking.id == Appeal.booking_id)
    if status == "open":
        stmt = stmt.where(Appeal.status == "open").order_by(Appeal.created_at)
    else:
        if status == "ruled":
            stmt = stmt.where(Appeal.status.in_(("ruled", "overruled")))
        stmt = stmt.order_by(Appeal.created_at.desc())
    rows = (await session.execute(stmt.limit(200))).all()
    names = await profiles_for(session, [a.filed_by_id for a, _ in rows])
    return [
        AppealSummary(
            id=a.id,
            booking_id=b.id,
            kind=b.kind,  # type: ignore[arg-type]
            listing_title=b.listing_title,
            reason=a.reason,
            status=a.status,  # type: ignore[arg-type]
            filed_by_name=names[a.filed_by_id].full_name if a.filed_by_id in names else "Student",
            created_at=a.created_at,
        )
        for a, b in rows
    ]


async def _detail(session, appeal: Appeal, staff) -> AppealDetail:
    booking = await session.get(Booking, appeal.booking_id)
    keys = await photo_keys(session, appeal.booking_id)

    def photos(found: list[str]) -> list[PhotoOut]:
        return [PhotoOut(id=k, url=storage.photo_url(k) or "") for k in found]

    def phase(name: str) -> list[PhotoOut]:
        return photos(keys.get((name, "renter"), []) + keys.get((name, "owner"), []))

    return AppealDetail(
        appeal=views.appeal_out(appeal),
        booking=await views.booking_out(session, booking, staff),
        pickup_photos=photos(
            keys.get(("pickup", "renter"), []) + keys.get(("pickup", "owner"), [])
        ),
        return_photos=photos(
            keys.get(("return", "renter"), []) + keys.get(("return", "owner"), [])
        ),
        extra_photos=photos(appeal.photo_keys),
        rulings=[
            RulingOut(
                id=r.id,
                ruled_by=r.ruled_by,
                ruled_at=r.ruled_at,
                overrules=r.overrules,
                summary=r.summary,
                charge_paise=r.charge_paise,
                refund_paise=r.refund_paise,
                trust_penalty=r.trust_penalty,
                remove_listing=r.remove_listing,
                account_action=r.account_action,
            )
            for r in await appeals.rulings_of(session, appeal.id)
        ],
    )


@router.get("/appeals/{appeal_id}", response_model=AppealDetail)
async def appeal(appeal_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    """The booking's timeline, both sides' handover photos, notes and any rulings."""
    return await _detail(session, await appeals.get_appeal(session, appeal_id), staff)


@router.post("/appeals/{appeal_id}/ruling", response_model=AppealDetail)
async def rule(appeal_id: uuid.UUID, body: RulingIn, staff: StaffAccount, session: SessionDep):
    """Any of: a charge or refund, a trust penalty, removing the listing, a
    suspension or ban. Both sides are notified and the booking moves on."""
    appeal = await appeals.rule(session, appeal_id, staff, body)
    await session.commit()
    return await _detail(session, appeal, staff)


@admin_router.post("/appeals/{appeal_id}/overrule", response_model=AppealDetail)
async def overrule(appeal_id: uuid.UUID, body: RulingIn, admin: AdminAccount, session: SessionDep):
    """Replace a moderator's ruling. Its effects are reversed where possible
    (a refund already paid out stays paid)."""
    appeal = await appeals.overrule(session, appeal_id, admin, body)
    await session.commit()
    return await _detail(session, appeal, admin)


@router.get("/escalations", response_model=list[EscalationOut])
async def escalations(staff: StaffAccount, session: SessionDep):
    """Overdue by an hour or more, owner escalations and stalled Proceeds."""
    raise not_implemented()


@router.get("/support/threads", response_model=list[SupportThreadSummary])
async def support_inbox(
    staff: StaffAccount, session: SessionDep, status: Literal["open", "closed"] = "open"
):
    raise not_implemented()


@router.get("/support/threads/{thread_id}", response_model=SupportThreadOut)
async def support_thread(thread_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    raise not_implemented()


@router.post(
    "/support/threads/{thread_id}/messages", response_model=SupportMessage, status_code=201
)
async def support_reply(
    thread_id: uuid.UUID, body: SupportMessageIn, staff: StaffAccount, session: SessionDep
):
    raise not_implemented()


@router.post("/support/threads/{thread_id}/close", response_model=SupportThreadOut)
async def close_thread(thread_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    raise not_implemented()


@router.get("/users", response_model=Page[StaffUserRow])
async def users(
    staff: StaffAccount,
    session: SessionDep,
    q: Annotated[str | None, Query(max_length=100)] = None,
    flagged: bool = False,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    """Search users; `flagged` lists only those with risk flags."""
    raise not_implemented()


@router.get("/users/{account_id}", response_model=StaffUserDetail)
async def user(account_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    raise not_implemented()


@router.post("/users/{account_id}/status", response_model=StaffUserDetail)
async def set_status(
    account_id: uuid.UUID, body: StatusChangeIn, staff: StaffAccount, session: SessionDep
):
    raise not_implemented()


@router.post("/users/{account_id}/trust-penalty", response_model=StaffUserDetail)
async def trust_penalty(
    account_id: uuid.UUID, body: PenaltyIn, staff: StaffAccount, session: SessionDep
):
    raise not_implemented()


@router.get("/listings", response_model=Page[ListingCard])
async def listings(
    staff: StaffAccount,
    session: SessionDep,
    status: ListingStatus | None = None,
    q: Annotated[str | None, Query(max_length=100)] = None,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    raise not_implemented()


@router.post("/listings/{listing_id}/remove", response_model=ListingCard)
async def remove_listing(
    listing_id: uuid.UUID, body: ReasonIn, staff: StaffAccount, session: SessionDep
):
    raise not_implemented()


@router.post("/reviews/{review_id}/remove", status_code=204)
async def remove_review(
    review_id: uuid.UUID, body: ReasonIn, staff: StaffAccount, session: SessionDep
) -> Response:
    raise not_implemented()
