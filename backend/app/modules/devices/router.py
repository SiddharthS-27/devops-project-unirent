from fastapi import APIRouter, Response
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.modules.devices import service
from app.modules.devices.schemas import PushTokenIn

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/push-tokens", status_code=204)
async def register_push_token(
    body: PushTokenIn, account: CurrentAccount, session: SessionDep
) -> Response:
    """Register this device for push. Call after every sign-in and token refresh."""
    await service.register(session, account.id, body.token, body.platform)
    await session.commit()
    return Response(status_code=204)


@router.delete("/push-tokens/{token}", status_code=204)
async def remove_push_token(token: str, account: CurrentAccount, session: SessionDep) -> Response:
    """Stop pushes to this device, for example on sign-out."""
    await service.remove(session, token, account.id)
    await session.commit()
    return Response(status_code=204)
