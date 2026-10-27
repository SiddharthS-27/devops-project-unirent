import hmac
from typing import Annotated

from fastapi import Header

from app.core.config import get_settings
from app.core.errors import ApiError


async def require_service_token(
    service_token: Annotated[str | None, Header(alias="X-Service-Token")] = None,
) -> None:
    """Internal routes are for the workers only."""
    expected = get_settings().service_token
    if not service_token or not hmac.compare_digest(service_token, expected):
        raise ApiError(401, "SERVICE_TOKEN_REQUIRED", "Internal route")
