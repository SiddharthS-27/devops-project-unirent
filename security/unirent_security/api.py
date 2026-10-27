"""HTTP routes owned by the security package. The backend mounts these under /api/v1."""

from fastapi import APIRouter, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security import microsoft, staff_auth, tokens
from unirent_security.accounts import find_or_create_student
from unirent_security.config import get_settings
from unirent_security.db import SessionDep
from unirent_security.errors import ApiError
from unirent_security.models import Account
from unirent_security.roles import AdminAccount
from unirent_security.schemas import (
    AccountOut,
    MicrosoftSignIn,
    MockTokenOut,
    MockTokenRequest,
    ModeratorCreate,
    RefreshRequest,
    StaffAccountOut,
    StaffLogin,
    StaffPasswordChange,
    TokenPair,
)

auth_router = APIRouter(prefix="/auth", tags=["auth"])
admin_router = APIRouter(prefix="/admin/moderators", tags=["admin"])


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


def _staff_out(account: Account) -> StaffAccountOut:
    return StaffAccountOut(
        id=account.id,
        email=account.email,
        name=account.display_name,
        role=account.role,
        status=account.status,
        created_at=account.created_at,
        last_login_at=account.last_login_at,
    )


@admin_router.get("", response_model=list[StaffAccountOut])
async def list_moderators(_: AdminAccount, session: SessionDep) -> list[StaffAccountOut]:
    rows = await session.scalars(
        select(Account).where(Account.role == "moderator").order_by(Account.created_at)
    )
    return [_staff_out(a) for a in rows]


@admin_router.post("", response_model=StaffAccountOut, status_code=201)
async def create_moderator(
    body: ModeratorCreate, admin: AdminAccount, session: SessionDep
) -> StaffAccountOut:
    """Create a moderator with a temporary password they replace on first login."""
    account = await staff_auth.create_staff_account(
        session, str(body.email), body.name, body.temporary_password
    )
    await session.commit()
    await session.refresh(account)
    return _staff_out(account)
