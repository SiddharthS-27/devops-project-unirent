"""Account lookups other packages use, and sign-in account creation."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security import db
from unirent_security.config import get_settings
from unirent_security.errors import ApiError, not_found
from unirent_security.microsoft import MicrosoftIdentity
from unirent_security.models import STATUSES, Account
from unirent_security.tokens import revoke_all


@dataclass(frozen=True)
class AccountInfo:
    id: uuid.UUID
    email: str
    role: str
    status: str
    display_name: str | None
    phone: str | None
    phone_verified_at: datetime | None
    created_at: datetime


def _info(account: Account) -> AccountInfo:
    return AccountInfo(
        id=account.id,
        email=account.email,
        role=account.role,
        status=account.status,
        display_name=account.display_name,
        phone=account.phone,
        phone_verified_at=account.phone_verified_at,
        created_at=account.created_at,
    )


async def get_account(account_id: uuid.UUID) -> AccountInfo | None:
    async with db.sessionmaker()() as session:
        account = await session.get(Account, account_id)
        return _info(account) if account else None


async def get_accounts(account_ids: list[uuid.UUID]) -> dict[uuid.UUID, AccountInfo]:
    if not account_ids:
        return {}
    async with db.sessionmaker()() as session:
        rows = await session.scalars(select(Account).where(Account.id.in_(account_ids)))
        return {a.id: _info(a) for a in rows}


def ensure_can_sign_in(account: Account) -> None:
    if account.status == "banned":
        raise ApiError(403, "ACCOUNT_BANNED", "This account is banned")
    if account.status == "deactivated":
        raise ApiError(403, "ACCOUNT_DEACTIVATED", "This account is deactivated")


async def find_or_create_student(session: AsyncSession, identity: MicrosoftIdentity) -> Account:
    """Accounts are keyed by Microsoft's object ID, so a renamed email still matches."""
    account = await session.scalar(select(Account).where(Account.ms_oid == identity.oid))
    if account is None:
        clash = await session.scalar(select(Account).where(Account.email == identity.email))
        if clash is not None:
            raise ApiError(409, "EMAIL_IN_USE", "This email belongs to another account")
        account = Account(
            id=uuid.uuid4(),
            email=identity.email,
            role="student",
            status="active",
            display_name=identity.name,
            ms_oid=identity.oid,
        )
        session.add(account)
    elif account.email != identity.email:
        account.email = identity.email
    ensure_can_sign_in(account)
    account.last_login_at = datetime.now(UTC)
    await session.flush()
    return account


def _status_key(account_id: uuid.UUID) -> str:
    return f"security:status:{account_id}"


async def status_override(account_id: uuid.UUID) -> str | None:
    """A status change newer than the caller's access token, if there is one."""
    return await db.redis().get(_status_key(account_id))


async def set_account_status(
    account_id: uuid.UUID,
    status: str,
    by: uuid.UUID | None,
    reason: str,
    session: AsyncSession | None = None,
) -> str:
    """Suspend, ban, deactivate or reactivate an account. Returns the old status.

    Suspended accounts can't list, request or pay but can finish open handovers.
    Banned and deactivated accounts can't sign in, and lose every refresh token.
    The new status takes effect at once, ahead of the 15-minute access tokens."""
    if status not in STATUSES:
        raise ApiError(422, "INVALID_STATUS", f"Unknown status {status!r}")
    if session is None:
        async with db.sessionmaker()() as own_session:
            previous = await set_account_status(account_id, status, by, reason, own_session)
            await own_session.commit()
            return previous

    account = await session.get(Account, account_id, with_for_update=True)
    if account is None:
        raise not_found("Account")
    if account.role == "admin" and status != "active":
        raise ApiError(403, "CANNOT_CHANGE_ADMIN", "The admin account can't be suspended")
    previous = account.status
    account.status = status
    account.status_reason = reason
    if status in ("banned", "deactivated"):
        await revoke_all(session, account_id)
    await session.flush()

    ttl = get_settings().access_token_ttl_seconds + 300
    await db.redis().set(_status_key(account_id), status, ex=ttl)
    return previous
