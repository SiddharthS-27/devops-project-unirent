"""Routes the workers call. Mounted at /internal, outside /api/v1, behind the service token."""

import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select

from app.core.clock import now
from app.core.deps import SessionDep
from app.core.errors import not_found
from app.core.internal_auth import require_service_token
from app.core.models import Timer
from app.modules.bookings import timer_rules
from app.modules.bookings.models import Booking
from app.modules.devices import service as devices
from app.modules.devices.schemas import PushTokensOut
from app.modules.internal.schemas import (
    DueTimer,
    DueTimers,
    FireResult,
    SavedSearchMatch,
    SavedSearchMatches,
)
from app.modules.listings.models import Listing
from app.modules.search import saved

router = APIRouter(
    prefix="/internal", tags=["internal"], dependencies=[Depends(require_service_token)]
)


@router.get("/accounts/{account_id}/push-tokens", response_model=PushTokensOut)
async def push_tokens(account_id: uuid.UUID, session: SessionDep) -> PushTokensOut:
    return PushTokensOut(tokens=await devices.tokens_for(session, account_id))


@router.delete("/push-tokens/{token}", status_code=204)
async def delete_push_token(token: str, session: SessionDep) -> Response:
    """The push sender drops tokens FCM reports as unregistered."""
    await devices.remove(session, token)
    await session.commit()
    return Response(status_code=204)


@router.get("/timers/due", response_model=DueTimers)
async def due_timers(session: SessionDep, limit: int = 100) -> DueTimers:
    """Timers whose time has come, oldest first, for the timer runner."""
    rows = await session.scalars(
        select(Timer)
        .where(Timer.fired_at.is_(None), Timer.cancelled_at.is_(None), Timer.due_at <= now())
        .order_by(Timer.due_at)
        .limit(min(limit, 500))
    )
    return DueTimers(
        timers=[DueTimer(id=t.id, kind=t.kind, ref_id=t.ref_id, due_at=t.due_at) for t in rows]
    )


@router.post("/timers/{timer_id}/fire", response_model=FireResult)
async def fire_timer(timer_id: uuid.UUID, session: SessionDep) -> FireResult:
    """Run the rule for one timer. Firing twice does nothing the second time."""
    timer = await session.scalar(
        select(Timer).where(Timer.id == timer_id).with_for_update(skip_locked=True)
    )
    if timer is None:
        exists = await session.get(Timer, timer_id)
        if exists is None:
            raise not_found("Timer")
        return FireResult(fired=False, outcome="busy")
    if timer.fired_at is not None or timer.cancelled_at is not None:
        return FireResult(fired=False, outcome="already_done")
    if timer.due_at > now():
        return FireResult(fired=False, outcome="not_due")
    rule = timer_rules.RULES.get(timer.kind)
    acted = False
    if rule is not None:
        booking = await session.get(Booking, timer.ref_id, with_for_update=True)
        if booking is not None:
            acted = await rule(session, booking)
    timer.fired_at = now()
    timer.attempts += 1
    await session.commit()
    return FireResult(fired=True, outcome="applied" if acted else "nothing_to_do")


@router.get("/saved-searches/matches", response_model=SavedSearchMatches)
async def saved_search_matches(listing_id: uuid.UUID, session: SessionDep) -> SavedSearchMatches:
    """Who to push when a listing is published. Empty unless the listing is active."""
    listing = await session.get(Listing, listing_id)
    if listing is None:
        raise not_found("Listing")
    matches = [] if listing.status != "active" else await saved.searches_matching(session, listing)
    return SavedSearchMatches(
        listing_id=listing.id,
        title=listing.title,
        matches=[
            SavedSearchMatch(saved_search_id=m.id, account_id=m.account_id, name=m.name or m.q)
            for m in matches
        ],
    )
