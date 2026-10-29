"""Routes the workers call. Mounted at /internal, outside /api/v1, behind the service token."""

import uuid

from fastapi import APIRouter, Depends, Response

from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.internal_auth import require_service_token
from app.modules.devices import service as devices
from app.modules.devices.schemas import PushTokensOut
from app.modules.internal.schemas import DueTimers, FireResult, SavedSearchMatches

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
    raise not_implemented()


@router.post("/timers/{timer_id}/fire", response_model=FireResult)
async def fire_timer(timer_id: uuid.UUID, session: SessionDep) -> FireResult:
    """Run the rule for one timer. Firing twice does nothing the second time."""
    raise not_implemented()


@router.get("/saved-searches/matches", response_model=SavedSearchMatches)
async def saved_search_matches(listing_id: uuid.UUID, session: SessionDep) -> SavedSearchMatches:
    raise not_implemented()
