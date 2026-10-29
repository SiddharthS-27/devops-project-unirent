import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Query, Response
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.schemas import Page
from app.modules.listings.schemas import Category, ListingCard, ListingKind
from app.modules.search.schemas import (
    HomeOut,
    SavedSearchIn,
    SavedSearchOut,
    SortOrder,
    Suggestion,
)

router = APIRouter(tags=["search"])


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
    raise not_implemented()


@router.get("/search/suggest", response_model=list[Suggestion])
async def suggest(
    account: CurrentAccount,
    session: SessionDep,
    q: Annotated[str, Query(min_length=1, max_length=100)],
):
    """Type-ahead suggestions as the user types."""
    raise not_implemented()


@router.get("/home", response_model=HomeOut)
async def home(account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.get("/saved-searches", response_model=list[SavedSearchOut])
async def list_saved_searches(account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.post("/saved-searches", response_model=SavedSearchOut, status_code=201)
async def create_saved_search(body: SavedSearchIn, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.delete("/saved-searches/{saved_search_id}", status_code=204)
async def delete_saved_search(
    saved_search_id: uuid.UUID, account: CurrentAccount, session: SessionDep
) -> Response:
    raise not_implemented()
