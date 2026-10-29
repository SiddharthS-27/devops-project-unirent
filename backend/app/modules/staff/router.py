import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response
from unirent_security import AdminAccount, StaffAccount

from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.schemas import Page
from app.modules.help.schemas import (
    SupportMessage,
    SupportMessageIn,
    SupportThreadOut,
    SupportThreadSummary,
)
from app.modules.listings.schemas import ListingCard, ListingStatus
from app.modules.staff.schemas import (
    AppealDetail,
    AppealSummary,
    EscalationOut,
    PenaltyIn,
    ReasonIn,
    RulingIn,
    StaffUserDetail,
    StaffUserRow,
    StatusChangeIn,
)

router = APIRouter(prefix="/staff", tags=["staff"])
admin_router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/appeals", response_model=list[AppealSummary])
async def appeals(
    staff: StaffAccount, session: SessionDep, status: Literal["open", "ruled", "all"] = "open"
):
    raise not_implemented()


@router.get("/appeals/{appeal_id}", response_model=AppealDetail)
async def appeal(appeal_id: uuid.UUID, staff: StaffAccount, session: SessionDep):
    raise not_implemented()


@router.post("/appeals/{appeal_id}/ruling", response_model=AppealDetail)
async def rule(appeal_id: uuid.UUID, body: RulingIn, staff: StaffAccount, session: SessionDep):
    raise not_implemented()


@admin_router.post("/appeals/{appeal_id}/overrule", response_model=AppealDetail)
async def overrule(appeal_id: uuid.UUID, body: RulingIn, admin: AdminAccount, session: SessionDep):
    """Replace a moderator's ruling. Its effects are reversed where possible."""
    raise not_implemented()


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
