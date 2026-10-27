"""Who is calling: FastAPI dependencies built on UniRent access tokens."""

import uuid
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from unirent_security.errors import ApiError, forbidden, unauthenticated
from unirent_security.tokens import decode_access_token

STAFF_ROLES = frozenset({"moderator", "admin"})

_bearer = HTTPBearer(auto_error=False, description="UniRent access token")


@dataclass(frozen=True)
class AccountContext:
    id: uuid.UUID
    role: str
    status: str

    @property
    def is_staff(self) -> bool:
        return self.role in STAFF_ROLES

    @property
    def is_admin(self) -> bool:
        return self.role == "admin"


async def _context_from_token(token: str) -> AccountContext:
    claims = decode_access_token(token)
    if claims.get("pwd_change"):
        raise forbidden("PASSWORD_CHANGE_REQUIRED", "Set a new password first")
    ctx = AccountContext(id=uuid.UUID(claims["sub"]), role=claims["role"], status=claims["status"])
    if ctx.status in ("banned", "deactivated"):
        raise unauthenticated("ACCOUNT_DISABLED", "This account can't sign in")
    return ctx


async def current_account(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> AccountContext:
    """The signed-in account. 401 without a valid access token."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise unauthenticated()
    ctx = await _context_from_token(credentials.credentials)
    request.state.account = ctx
    return ctx


async def optional_account(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> AccountContext | None:
    """The signed-in account if a token was sent, for endpoints that also serve guests."""
    if credentials is None:
        return None
    return await current_account(request, credentials)


CurrentAccount = Annotated[AccountContext, Depends(current_account)]


def require_role(*roles: str):
    """Dependency: the caller must have one of these roles."""
    allowed = frozenset(roles)

    async def dependency(account: CurrentAccount) -> AccountContext:
        if account.role not in allowed:
            raise forbidden("ROLE_NOT_ALLOWED", "Your role can't do this")
        return account

    return dependency


async def require_active(account: CurrentAccount) -> AccountContext:
    """Dependency for starting anything new (listing, requesting, paying).
    Suspended accounts may still finish open handovers, which don't use this."""
    if account.status == "suspended":
        raise ApiError(403, "ACCOUNT_SUSPENDED", "Your account is suspended")
    return account


StaffAccount = Annotated[AccountContext, Depends(require_role("moderator", "admin"))]
AdminAccount = Annotated[AccountContext, Depends(require_role("admin"))]
ActiveAccount = Annotated[AccountContext, Depends(require_active)]
