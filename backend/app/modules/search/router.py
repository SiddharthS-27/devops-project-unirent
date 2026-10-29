import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Query, Response
from sqlalchemy import select
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.core.schemas import Page
from app.modules.listings.models import Listing
from app.modules.listings.schemas import (
    CATEGORY_LABELS,
    Category,
    CategoryOut,
    ListingCard,
    ListingKind,
)
from app.modules.listings.service import cards
from app.modules.search import saved, service
from app.modules.search.schemas import (
    HomeOut,
    SavedSearchIn,
    SavedSearchOut,
    SortOrder,
    Suggestion,
)

router = APIRouter(tags=["search"])
RECENT_LIMIT = 10


@router.get("/search", response_model=Page[ListingCard])
async def search(
    account: CurrentAccount,
    session: SessionDep,
    q: Annotated[str | None, Query(max_length=100)] = None,
    category: Category | None = None,
    kind: ListingKind | None = None,
    min_price_paise: Annotated[int | None, Query(ge=0)] = None,
    max_price_paise: Annotated[int | None, Query(ge=0)] = None,
    available_from: datetime | None = None,
    available_to: datetime | None = None,
    sort: SortOrder = "trust",
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    """Active listings. Sorted by the owner's lender trust by default; New owners
    rank at the campus median."""
    if available_from or available_to:
        kind = "rent"
    return await service.search(
        session,
        account,
        q=q,
        sort=sort,
        cursor=cursor,
        limit=limit,
        category=category,
        kind=kind,
        min_price_paise=min_price_paise,
        max_price_paise=max_price_paise,
        available_from=available_from,
        available_to=available_to,
    )


@router.get("/search/suggest", response_model=list[Suggestion])
async def suggest(
    account: CurrentAccount,
    session: SessionDep,
    q: Annotated[str, Query(min_length=1, max_length=100)],
):
    """Type-ahead suggestions as the user types."""
    return await service.suggest(session, q)


@router.get("/home", response_model=HomeOut)
async def home(account: CurrentAccount, session: SessionDep):
    """Category shortcuts, recently listed, and new matches for saved searches."""
    recent = await session.scalars(
        select(Listing)
        .where(Listing.status == "active", Listing.owner_id != account.id)
        .order_by(Listing.created_at.desc())
        .limit(RECENT_LIMIT)
    )
    return HomeOut(
        categories=[CategoryOut(key=k, label=v) for k, v in CATEGORY_LABELS.items()],  # type: ignore[arg-type]
        recent=await cards(session, list(recent)),
        saved_search_matches=await cards(session, await saved.recent_matches(session, account)),
    )


@router.get("/saved-searches", response_model=list[SavedSearchOut])
async def list_saved_searches(account: CurrentAccount, session: SessionDep):
    """With the number of new matches since you last looked."""
    out = await saved.list_saved(session, account)
    await session.commit()
    return out


@router.post("/saved-searches", response_model=SavedSearchOut, status_code=201)
async def create_saved_search(body: SavedSearchIn, account: CurrentAccount, session: SessionDep):
    """You get a push when a new listing matches."""
    out = await saved.create(session, account, body)
    await session.commit()
    return out


@router.delete("/saved-searches/{saved_search_id}", status_code=204)
async def delete_saved_search(
    saved_search_id: uuid.UUID, account: CurrentAccount, session: SessionDep
) -> Response:
    await saved.remove(session, account, saved_search_id)
    await session.commit()
    return Response(status_code=204)
