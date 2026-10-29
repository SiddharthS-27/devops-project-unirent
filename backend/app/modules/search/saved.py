"""Saved searches and matching new listings against them."""

import uuid

from sqlalchemy import Select, and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import AccountContext

from app.core.clock import now
from app.core.errors import ApiError, not_found
from app.modules.listings.models import Listing
from app.modules.search.models import SavedSearch
from app.modules.search.schemas import SavedSearchIn, SavedSearchOut
from app.modules.search.service import apply_filters, prefix_query, text_match

MAX_SAVED = 20


def matching(saved: SavedSearch) -> Select:
    """Active listings this saved search matches, not the searcher's own."""
    stmt = select(Listing).where(Listing.status == "active", Listing.owner_id != saved.account_id)
    stmt = apply_filters(
        stmt,
        category=saved.category,
        kind=saved.kind,
        min_price_paise=saved.min_price_paise,
        max_price_paise=saved.max_price_paise,
    )
    stmt, _ = text_match(stmt, saved.q)
    return stmt


async def _out(session: AsyncSession, saved: SavedSearch) -> SavedSearchOut:
    new = await session.scalar(
        select(func.count()).select_from(
            matching(saved).where(Listing.created_at > saved.last_viewed_at).subquery()
        )
    )
    return SavedSearchOut(
        id=saved.id,
        name=saved.name,
        q=saved.q,
        category=saved.category,  # type: ignore[arg-type]
        kind=saved.kind,  # type: ignore[arg-type]
        min_price_paise=saved.min_price_paise,
        max_price_paise=saved.max_price_paise,
        created_at=saved.created_at,
        new_match_count=new or 0,
    )


async def list_saved(session: AsyncSession, account: AccountContext) -> list[SavedSearchOut]:
    """Counts matches since the last look, then marks them seen."""
    rows = list(
        await session.scalars(
            select(SavedSearch)
            .where(SavedSearch.account_id == account.id)
            .order_by(SavedSearch.created_at.desc())
        )
    )
    out = [await _out(session, s) for s in rows]
    for saved in rows:
        saved.last_viewed_at = now()
    return out


async def create(
    session: AsyncSession, account: AccountContext, data: SavedSearchIn
) -> SavedSearchOut:
    if not any(data.model_dump().values()):
        raise ApiError(422, "EMPTY_SEARCH", "Add a search term or a filter to save")
    count = await session.scalar(select(func.count()).where(SavedSearch.account_id == account.id))
    if (count or 0) >= MAX_SAVED:
        raise ApiError(409, "TOO_MANY_SAVED_SEARCHES", f"You can save up to {MAX_SAVED}")
    at = now()
    saved = SavedSearch(
        id=uuid.uuid4(),
        account_id=account.id,
        tsquery=prefix_query(data.q) if data.q else None,
        created_at=at,
        last_viewed_at=at,
        **data.model_dump(),
    )
    session.add(saved)
    await session.flush()
    return await _out(session, saved)


async def remove(session: AsyncSession, account: AccountContext, saved_id: uuid.UUID) -> None:
    result = await session.execute(
        delete(SavedSearch).where(SavedSearch.id == saved_id, SavedSearch.account_id == account.id)
    )
    if not result.rowcount:
        raise not_found("Saved search")


async def searches_matching(session: AsyncSession, listing: Listing) -> list[SavedSearch]:
    """For the workers' matcher: saved searches a newly published listing satisfies."""
    price = listing.price_paise
    conditions = [
        SavedSearch.account_id != listing.owner_id,
        or_(SavedSearch.category.is_(None), SavedSearch.category == listing.category),
        or_(SavedSearch.kind.is_(None), SavedSearch.kind == listing.kind),
        or_(SavedSearch.min_price_paise.is_(None), SavedSearch.min_price_paise <= price),
        or_(SavedSearch.max_price_paise.is_(None), SavedSearch.max_price_paise >= price),
    ]
    text_ok = or_(
        SavedSearch.tsquery.is_(None),
        select(Listing.search_vector.op("@@")(func.to_tsquery("english", SavedSearch.tsquery)))
        .where(Listing.id == listing.id)
        .scalar_subquery(),
    )
    rows = await session.scalars(select(SavedSearch).where(and_(*conditions), text_ok))
    return list(rows)


async def recent_matches(
    session: AsyncSession, account: AccountContext, limit: int = 10
) -> list[Listing]:
    """Listings matching any of the student's saved searches since each was saved."""
    saved = list(
        await session.scalars(select(SavedSearch).where(SavedSearch.account_id == account.id))
    )
    if not saved:
        return []
    ids = set()
    for s in saved:
        rows = await session.scalars(
            matching(s).where(Listing.created_at > s.created_at).with_only_columns(Listing.id)
        )
        ids.update(rows)
    if not ids:
        return []
    rows = await session.scalars(
        select(Listing).where(Listing.id.in_(ids)).order_by(Listing.created_at.desc()).limit(limit)
    )
    return list(rows)
