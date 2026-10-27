"""HTTP routes owned by the security package. The backend mounts these under /api/v1."""

from fastapi import APIRouter, Response
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security import microsoft, staff_auth, tokens
from unirent_security.accounts import find_or_create_student
from unirent_security.config import get_settings
from unirent_security.db import SessionDep
from unirent_security.errors import ApiError
from unirent_security.models import Account
from unirent_security.schemas import (
    AccountOut,
    MicrosoftSignIn,
    MockTokenOut,
    MockTokenRequest,
    RefreshRequest,
    StaffLogin,
    StaffPasswordChange,
    TokenPair,
)

auth_router = APIRouter(prefix="/auth", tags=["auth"])


async def token_pair(
    session: AsyncSession,
    account: Account,
    refresh_token: str | None = None,
    must_change_password: bool = False,
) -> TokenPair:
    if refresh_token is None:
        refresh_token, _ = await tokens.issue_refresh_token(session, account.id)
    return TokenPair(
        access_token=tokens.issue_access_token(account, must_change_password),
        refresh_token=refresh_token,
        expires_in=get_settings().access_token_ttl_seconds,
        account=AccountOut(
            id=account.id,
            email=account.email,
            role=account.role,
            status=account.status,
            must_change_password=must_change_password,
        ),
    )


@auth_router.post("/microsoft", response_model=TokenPair)
async def sign_in_with_microsoft(body: MicrosoftSignIn, session: SessionDep) -> TokenPair:
    """Exchange a Microsoft ID token for UniRent tokens. Creates the account on first sign-in."""
    identity = await microsoft.verify_id_token(body.id_token)
    account = await find_or_create_student(session, identity)
    pair = await token_pair(session, account)
    await session.commit()
    return pair


@auth_router.post("/microsoft/mock-token", response_model=MockTokenOut)
async def mock_microsoft_token(body: MockTokenRequest) -> MockTokenOut:
    """Development only: a signed stand-in for a Microsoft ID token."""
    settings = get_settings()
    if settings.ms_auth_mode != "mock" or not settings.mock_allowed():
        raise ApiError(404, "NOT_FOUND", "Not found")
    return MockTokenOut(id_token=microsoft.mock_id_token(str(body.email), body.name))


@auth_router.post("/refresh", response_model=TokenPair)
async def refresh(body: RefreshRequest, session: SessionDep) -> TokenPair:
    """Rotate a refresh token. Using one twice signs out every device of that sign-in."""
    account, new_refresh = await tokens.rotate_refresh_token(session, body.refresh_token)
    pair = await token_pair(session, account, refresh_token=new_refresh)
    await session.commit()
    return pair


@auth_router.post("/logout", status_code=204)
async def logout(body: RefreshRequest, session: SessionDep) -> Response:
    await tokens.revoke_refresh_token(session, body.refresh_token)
    await session.commit()
    return Response(status_code=204)


@auth_router.post("/staff/login", response_model=TokenPair)
async def staff_login(body: StaffLogin, session: SessionDep) -> TokenPair:
    """Moderator and admin login. While `must_change_password` is true, the token
    only works for /auth/staff/password."""
    account, credential = await staff_auth.authenticate(session, str(body.email), body.password)
    pair = await token_pair(session, account, must_change_password=credential.must_change_password)
    await session.commit()
    return pair


@auth_router.post("/staff/password", response_model=TokenPair)
async def staff_change_password(body: StaffPasswordChange, session: SessionDep) -> TokenPair:
    """Set a new password; also how a new moderator replaces the temporary one."""
    account, _ = await staff_auth.change_password(
        session, str(body.email), body.current_password, body.new_password
    )
    await tokens.revoke_all(session, account.id)
    pair = await token_pair(session, account)
    await session.commit()
    return pair
