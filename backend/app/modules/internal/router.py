"""Routes the workers call. Mounted at /internal, outside /api/v1, behind the service token."""

import uuid

from fastapi import APIRouter, Depends, Response

from app.core.deps import SessionDep
from app.core.internal_auth import require_service_token
from app.modules.devices import service as devices
from app.modules.devices.schemas import PushTokensOut

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
