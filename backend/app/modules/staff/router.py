import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response
from sqlalchemy import or_, select
from unirent_security import (
    AccountContext,
    AdminAccount,
    StaffAccount,
    audit,
    get_account,
    get_accounts,
    search_accounts,
    set_account_status,
)

from app.core import storage
from app.core.clock import now
from app.core.deps import SessionDep
from app.core.errors import not_found
from app.core.outbox import emit
from app.core.pagination import decode_offset, encode_offset
from app.core.schemas import Page, PhotoOut
from app.modules.bookings import views
from app.modules.bookings.handover import photo_keys
from app.modules.bookings.models import Booking
from app.modules.help import support
from app.modules.help.schemas import (
    SupportMessage,
    SupportMessageIn,
    SupportThreadOut,
    SupportThreadSummary,
)
from app.modules.listings.models import Listing
from app.modules.listings.schemas import ListingCard, ListingStatus
from app.modules.listings.service import cards
from app.modules.moderation import appeals, oversight
from app.modules.moderation.models import Appeal, TrustPenalty
from app.modules.profiles.models import Profile
from app.modules.profiles.service import profile_for_viewer, profiles_for
from app.modules.reviews.models import Review
from app.modules.staff.schemas import (
    AppealDetail,
    AppealSummary,
    EscalationOut,
    PenaltyIn,
    PenaltyOut,
    ReasonIn,
    RulingIn,
    RulingOut,
    StaffUserDetail,
    StaffUserRow,
    StatusChangeIn,
)
from app.modules.trust import service as trust
from app.modules.trust.models import TrustScore

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
    """Overdue by an hour or more, owner escalations and stalled Proceeds, with
    residence details for following up in person."""
    out = []
    for booking, kind in await oversight.escalated_bookings(session):
        renter = await profile_for_viewer(session, staff, booking.renter_id)
        owner = await profile_for_viewer(session, staff, booking.owner_id)
        summary = (
            await views.summaries(
                session,
                AccountContext(booking.owner_id, "student", "active"),
                role="owner",
                group=None,
                listing_id=booking.listing_id,
                cursor=None,
                limit=50,
            )
        ).items
        since = (
            booking.escalated_at
            if kind == "owner_escalated"
            else booking.overdue_since
            if kind == "overdue"
            else booking.return_completed_at
        )
        out.append(
            EscalationOut(
                booking=next(b for b in summary if b.id == booking.id),
                kind=kind,  # type: ignore[arg-type]
                since=since,  # type: ignore[arg-type]
                renter_id=booking.renter_id,
                renter_name=renter.full_name,
                renter_phone=renter.phone,
                renter_residence=getattr(renter, "residence", None),
                owner_name=owner.full_name,
                owner_phone=owner.phone,
                note=booking.escalation_note,
            )
        )
    return out


@router.get("/support/threads", response_model=list[SupportThreadSummary])
async def support_inbox(
    staff: StaffAccount, session: SessionDep, status: Literal["open", "closed"] = "open"
):
    """Chats handed off from the help bot, latest activity first."""
    return await support.summaries(session, status=status)


@router.get("/support/threads/{thread_id}", response_model=SupportThreadOut)
async def support_thread(thread_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    return await support.thread_out(session, await support.get_thread(session, thread_id, staff))


@router.post(
    "/support/threads/{thread_id}/messages", response_model=SupportMessage, status_code=201
)
async def support_reply(
    thread_id: uuid.UUID, body: SupportMessageIn, staff: StaffAccount, session: SessionDep
):
    """Answer in the same chat; the student gets a push."""
    message = await support.post(session, thread_id, staff, body.body)
    await session.commit()
    return support.message_out(message)


@router.post("/support/threads/{thread_id}/close", response_model=SupportThreadOut)
async def close_thread(thread_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    thread = await support.close(session, thread_id, staff)
    await session.commit()
    return await support.thread_out(session, thread)


async def _rows(session, account_ids: list[uuid.UUID]) -> list[StaffUserRow]:
    profiles = {
        p.account_id: p
        for p in await session.scalars(select(Profile).where(Profile.account_id.in_(account_ids)))
    }
    accounts = await get_accounts(account_ids)
    trust = {
        t.account_id: t
        for t in await session.scalars(
            select(TrustScore).where(TrustScore.account_id.in_(account_ids))
        )
    }
    flags = await oversight.risk_flags(session, account_ids)
    rows = []
    for account_id in account_ids:
        account = accounts.get(account_id)
        if account is None:
            continue
        score = trust.get(account_id)
        rows.append(
            StaffUserRow(
                account_id=account_id,
                full_name=profiles[account_id].full_name if account_id in profiles else None,
                email=account.email,
                status=account.status,
                lender_trust=score.lender_score if score else None,
                renter_trust=score.renter_score if score else None,
                risk_flags=flags.get(account_id, []),
            )
        )
    return rows


@router.get("/users", response_model=Page[StaffUserRow])
async def users(
    staff: StaffAccount,
    session: SessionDep,
    q: Annotated[str | None, Query(max_length=100)] = None,
    flagged: bool = False,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    """Search by name, roll number or email; `flagged` lists only those with risk flags."""
    offset = decode_offset(cursor)
    if flagged:
        ids = await oversight.flagged_accounts(session)
    else:
        stmt = select(Profile.account_id).order_by(Profile.created_at.desc())
        if q:
            like = f"%{q}%"
            stmt = stmt.where(or_(Profile.full_name.ilike(like), Profile.roll_number.ilike(like)))
        ids = list(await session.scalars(stmt.limit(500)))
        if q and "@" in q or (q and not ids):
            ids += [a.id for a in await search_accounts(q) if a.id not in ids]
    page = ids[offset : offset + limit]
    next_cursor = encode_offset(offset + limit) if len(ids) > offset + limit else None
    return Page[StaffUserRow](items=await _rows(session, page), next_cursor=next_cursor)


async def _user_detail(session, staff, account_id: uuid.UUID) -> StaffUserDetail:
    account = await get_account(account_id)
    if account is None or account.role != "student":
        raise not_found("User")
    profile = None
    if await session.get(Profile, account_id) is not None:
        profile = await profile_for_viewer(session, staff, account_id)
    subject = AccountContext(account_id, "student", account.status)
    bookings = []
    for role in ("renter", "owner"):
        page = await views.summaries(
            session, subject, role=role, group=None, listing_id=None, cursor=None, limit=20
        )
        bookings += page.items
    penalties = await session.scalars(
        select(TrustPenalty)
        .where(TrustPenalty.account_id == account_id, TrustPenalty.revoked_at.is_(None))
        .order_by(TrustPenalty.created_at.desc())
    )
    return StaffUserDetail(
        profile=profile,  # type: ignore[arg-type]
        email=account.email,
        status=account.status,
        bookings=sorted(bookings, key=lambda b: b.updated_at, reverse=True),
        risk_flags=(await oversight.risk_flags(session, [account_id]))[account_id],
        penalties=[
            PenaltyOut(role=p.role, points=p.points, reason=p.reason, by=p.by, at=p.created_at)  # type: ignore[arg-type]
            for p in penalties
        ],
    )


@router.get("/users/{account_id}", response_model=StaffUserDetail)
async def user(account_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    """Profile with email and roll number, history, risk flags and penalties."""
    return await _user_detail(session, staff, account_id)


@router.post("/users/{account_id}/status", response_model=StaffUserDetail)
async def set_status(
    account_id: uuid.UUID, body: StatusChangeIn, staff: StaffAccount, session: SessionDep
):
    """Suspend (can't list, request or pay, can finish open handovers), ban (can't
    sign in) or reactivate."""
    account = await get_account(account_id)
    if account is None or account.role != "student":
        raise not_found("User")
    await set_account_status(account_id, body.status, staff.id, body.reason, session)
    emit(
        session,
        "AccountStatusChanged",
        account_id,
        {"account_id": str(account_id), "status": body.status, "reason": body.reason},
    )
    await session.commit()
    return await _user_detail(session, staff, account_id)


@router.post("/users/{account_id}/trust-penalty", response_model=StaffUserDetail)
async def trust_penalty(
    account_id: uuid.UUID, body: PenaltyIn, staff: StaffAccount, session: SessionDep
):
    if await get_account(account_id) is None:
        raise not_found("User")
    session.add(
        TrustPenalty(
            id=uuid.uuid4(),
            account_id=account_id,
            role=body.role,
            points=body.points,
            reason=body.reason,
            by=staff.id,
            created_at=now(),
        )
    )
    await audit.record(
        staff,
        "moderation.trust_penalty",
        audit.target("account", account_id),
        body.model_dump(),
        session=session,
    )
    await session.flush()
    await trust.recompute(session, account_id)
    await session.commit()
    return await _user_detail(session, staff, account_id)


@router.get("/listings", response_model=Page[ListingCard])
async def listings(
    staff: StaffAccount,
    session: SessionDep,
    status: ListingStatus | None = None,
    q: Annotated[str | None, Query(max_length=100)] = None,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    offset = decode_offset(cursor)
    stmt = select(Listing).order_by(Listing.created_at.desc())
    if status:
        stmt = stmt.where(Listing.status == status)
    if q:
        stmt = stmt.where(Listing.title.ilike(f"%{q}%"))
    rows = list(await session.scalars(stmt.offset(offset).limit(limit + 1)))
    next_cursor = encode_offset(offset + limit) if len(rows) > limit else None
    return Page[ListingCard](items=await cards(session, rows[:limit]), next_cursor=next_cursor)


@router.post("/listings/{listing_id}/remove", response_model=ListingCard)
async def remove_listing(
    listing_id: uuid.UUID, body: ReasonIn, staff: StaffAccount, session: SessionDep
):
    listing = await session.get(Listing, listing_id, with_for_update=True)
    if listing is None:
        raise not_found("Listing")
    listing.status = "removed"
    listing.removed_reason = body.reason
    listing.updated_at = now()
    await audit.record(
        staff,
        "moderation.listing_removed",
        audit.target("listing", listing_id),
        {"reason": body.reason},
        session=session,
    )
    await session.commit()
    return (await cards(session, [listing]))[0]


@router.post("/reviews/{review_id}/remove", status_code=204)
async def remove_review(
    review_id: uuid.UUID, body: ReasonIn, staff: StaffAccount, session: SessionDep
) -> Response:
    """Hide an abusive review; the reviewee's trust is recomputed without it."""
    review = await session.get(Review, review_id, with_for_update=True)
    if review is None:
        raise not_found("Review")
    review.removed_at = now()
    review.removed_reason = body.reason
    await audit.record(
        staff,
        "moderation.review_removed",
        audit.target("review", review_id),
        {"reason": body.reason},
        session=session,
    )
    await session.flush()
    await trust.recompute(session, review.reviewee_id)
    await session.commit()
    return Response(status_code=204)
