"""Search: PostgreSQL full-text search over title, description and category,
plus pg_trgm word similarity for type-ahead."""

import re
from datetime import datetime

from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import AccountContext

from app.core.pagination import decode_offset, encode_offset
from app.core.schemas import Page
from app.modules.listings.models import Listing
from app.modules.listings.schemas import ListingCard
from app.modules.listings.service import cards
from app.modules.search.schemas import Suggestion
from app.modules.trust.models import TrustScore

DEFAULT_MEDIAN = 50

SUGGEST_LIMIT = 8
SUGGEST_THRESHOLD = 0.3
_WORD = re.compile(r"[\w]+", re.UNICODE)


def prefix_query(q: str) -> str | None:
    """'canon cam' -> 'canon:* & cam:*', so partly typed words still match."""
    words = _WORD.findall(q.lower())[:8]
    return " & ".join(f"{w}:*" for w in words) if words else None


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def text_match(stmt: Select, q: str | None) -> tuple[Select, object | None]:
    """Filter by the query; return the relevance expression to sort by."""
    if not q or not (tsquery := prefix_query(q)):
        return stmt, None
    query = func.to_tsquery("english", tsquery)
    stmt = stmt.where(
        or_(
            Listing.search_vector.op("@@")(query),
            Listing.title.ilike(f"%{_escape_like(q.strip())}%", escape="\\"),
        )
    )
    return stmt, func.ts_rank(Listing.search_vector, query) + func.word_similarity(q, Listing.title)


def price_expr():
    return func.coalesce(
        Listing.sale_price_paise, Listing.price_per_day_paise, Listing.price_per_hour_paise
    )


async def available_between(stmt: Select, start: datetime | None, end: datetime | None) -> Select:
    """Rent listings with no approved booking in [start, end). Filled in by bookings."""
    return stmt


async def campus_median(session: AsyncSession) -> float:
    """The median lender trust; owners still New rank as if they had it."""
    median = await session.scalar(
        select(func.percentile_cont(0.5).within_group(TrustScore.lender_score.asc())).where(
            TrustScore.lender_score.is_not(None)
        )
    )
    return float(median) if median is not None else DEFAULT_MEDIAN


def apply_filters(
    stmt: Select,
    *,
    category: str | None = None,
    kind: str | None = None,
    min_price_paise: int | None = None,
    max_price_paise: int | None = None,
) -> Select:
    if category:
        stmt = stmt.where(Listing.category == category)
    if kind:
        stmt = stmt.where(Listing.kind == kind)
    if min_price_paise is not None:
        stmt = stmt.where(price_expr() >= min_price_paise)
    if max_price_paise is not None:
        stmt = stmt.where(price_expr() <= max_price_paise)
    return stmt


async def search(
    session: AsyncSession,
    viewer: AccountContext,
    *,
    q: str | None,
    sort: str,
    cursor: str | None,
    limit: int,
    category: str | None = None,
    kind: str | None = None,
    min_price_paise: int | None = None,
    max_price_paise: int | None = None,
    available_from: datetime | None = None,
    available_to: datetime | None = None,
) -> Page[ListingCard]:
    stmt = select(Listing).where(Listing.status == "active")
    if available_from or available_to:
        stmt = await available_between(stmt, available_from, available_to)
    stmt = apply_filters(
        stmt,
        category=category,
        kind=kind,
        min_price_paise=min_price_paise,
        max_price_paise=max_price_paise,
    )
    stmt, relevance = text_match(stmt, q)
    if sort == "trust":
        stmt = stmt.outerjoin(TrustScore, TrustScore.account_id == Listing.owner_id)
        trust = func.coalesce(TrustScore.lender_score, await campus_median(session))
        order = [trust.desc()]
        if relevance is not None:
            order.append(relevance.desc())
        order.append(Listing.created_at.desc())
    else:
        order = {
            "newest": [Listing.created_at.desc()],
            "price_asc": [price_expr().asc(), Listing.created_at.desc()],
            "price_desc": [price_expr().desc(), Listing.created_at.desc()],
        }[sort]
    offset = decode_offset(cursor)
    rows = list(
        await session.scalars(stmt.order_by(*order, Listing.id).offset(offset).limit(limit + 1))
    )
    next_cursor = encode_offset(offset + limit) if len(rows) > limit else None
    return Page[ListingCard](items=await cards(session, rows[:limit]), next_cursor=next_cursor)


async def suggest(session: AsyncSession, q: str) -> list[Suggestion]:
    """Up to eight active listings whose titles match what has been typed so far."""
    q = q.strip()
    if not q:
        return []
    similarity = func.word_similarity(q, Listing.title)
    rows = await session.execute(
        select(Listing.id, Listing.title, Listing.category, Listing.kind)
        .where(
            Listing.status == "active",
            or_(
                Listing.title.ilike(f"%{_escape_like(q)}%", escape="\\"),
                similarity > SUGGEST_THRESHOLD,
            ),
        )
        .order_by(similarity.desc(), Listing.created_at.desc())
        .limit(SUGGEST_LIMIT)
    )
    return [
        Suggestion(listing_id=r.id, title=r.title, category=r.category, kind=r.kind) for r in rows
    ]
