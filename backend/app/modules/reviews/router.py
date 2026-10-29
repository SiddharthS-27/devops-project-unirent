import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Query
from sqlalchemy import or_, select
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.core.pagination import decode_offset, encode_offset
from app.core.schemas import Page
from app.modules.bookings import views
from app.modules.bookings.models import Booking
from app.modules.bookings.schemas import BookingSummary
from app.modules.profiles.service import profiles_for
from app.modules.reviews.models import Review
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
    """Revealed reviews only, newest first."""
    offset = decode_offset(cursor)
    rows = list(
        await session.scalars(
            select(Review)
            .where(
                Review.reviewee_id == account_id,
                Review.reviewee_role == role,
                Review.revealed_at.is_not(None),
                Review.removed_at.is_(None),
            )
            .order_by(Review.created_at.desc(), Review.id)
            .offset(offset)
            .limit(limit + 1)
        )
    )
    page = rows[:limit]
    names = await profiles_for(session, [r.reviewer_id for r in page])
    items = [
        ReviewOut(
            id=r.id,
            review_type=r.review_type,  # type: ignore[arg-type]
            overall=float(r.overall),
            ratings=r.ratings,
            comment=r.comment,
            reviewer_id=r.reviewer_id,
            reviewer_name=names[r.reviewer_id].full_name if r.reviewer_id in names else "Student",
            created_at=r.created_at,
        )
        for r in page
    ]
    next_cursor = encode_offset(offset + limit) if len(rows) > limit else None
    return Page[ReviewOut](items=items, next_cursor=next_cursor)


@router.get("/me/pending-reviews", response_model=list[BookingSummary])
async def pending_reviews(account: CurrentAccount, session: SessionDep):
    """Bookings waiting for my review. The app keeps the user here until they review."""
    reviewed = select(Review.booking_id).where(Review.reviewer_id == account.id)
    waiting = await session.scalars(
        select(Booking.id).where(
            Booking.status == "awaiting_reviews",
            or_(Booking.renter_id == account.id, Booking.owner_id == account.id),
            Booking.id.not_in(reviewed),
        )
    )
    ids = set(waiting)
    out = []
    for role in ("renter", "owner"):
        page = await views.summaries(
            session, account, role=role, group="active", listing_id=None, cursor=None, limit=50
        )
        out += [b for b in page.items if b.id in ids]
    return out
