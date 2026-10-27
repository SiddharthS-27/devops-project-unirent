"""Account lookups other packages use, and sign-in account creation."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security import db
from unirent_security.errors import ApiError
from unirent_security.microsoft import MicrosoftIdentity
from unirent_security.models import Account


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
