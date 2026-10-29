import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Query
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.schemas import Page
from app.modules.bookings.schemas import BookingSummary
from app.modules.reviews.schemas import ReviewOut

router = APIRouter(tags=["reviews"])


@router.get("/profiles/{account_id}/reviews", response_model=Page[ReviewOut])
async def reviews_of(
    account_id: uuid.UUID,
    account: CurrentAccount,
    session: SessionDep,
    role: Literal["lender", "renter"] = "lender",
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    """Revealed reviews only."""
    raise not_implemented()


@router.get("/me/pending-reviews", response_model=list[BookingSummary])
async def pending_reviews(account: CurrentAccount, session: SessionDep):
    """Bookings waiting for my review. The app keeps the user here until they review."""
    raise not_implemented()
