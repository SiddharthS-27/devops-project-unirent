"""Staff (moderator and admin) email and password sign-in."""

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security.accounts import ensure_can_sign_in
from unirent_security.config import get_settings
from unirent_security.errors import ApiError
from unirent_security.metrics import AUTH_FAILURES
from unirent_security.models import Account, StaffCredential
from unirent_security.passwords import hash_secret, needs_rehash, verify_secret

STAFF_ROLES = ("moderator", "admin")
MIN_PASSWORD_LENGTH = 10


def _now() -> datetime:
    return datetime.now(UTC)


def _invalid() -> ApiError:
    AUTH_FAILURES.labels(reason="INVALID_CREDENTIALS").inc()
    return ApiError(401, "INVALID_CREDENTIALS", "Wrong email or password")


def check_password_strength(password: str, email: str) -> None:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ApiError(
            422,
            "WEAK_PASSWORD",
            f"Use at least {MIN_PASSWORD_LENGTH} characters",
        )
    if password.lower() == email.lower() or password.lower() in email.lower():
        raise ApiError(422, "WEAK_PASSWORD", "The password can't contain your email")


async def authenticate(
    session: AsyncSession, email: str, password: str
) -> tuple[Account, StaffCredential]:
    """Check a staff login. Five wrong passwords lock the account for 15 minutes."""
    settings = get_settings()
    row = (
        await session.execute(
            select(Account, StaffCredential)
            .join(StaffCredential, StaffCredential.account_id == Account.id)
            .where(Account.email == email.strip().lower(), Account.role.in_(STAFF_ROLES))
            .with_for_update(of=StaffCredential)
        )
    ).first()
    if row is None:
        verify_secret(password, None)  # same work as a real check
        raise _invalid()
    account, credential = row

    if credential.locked_until and credential.locked_until > _now():
        raise ApiError(
            423,
            "ACCOUNT_LOCKED",
            "Too many wrong passwords. Try again later",
            details={"locked_until": credential.locked_until.isoformat()},
        )

    if not verify_secret(password, credential.password_hash):
        credential.failed_attempts += 1
        if credential.failed_attempts >= settings.staff_max_failed_logins:
            credential.locked_until = _now() + timedelta(minutes=settings.staff_lockout_minutes)
            credential.failed_attempts = 0
        await session.commit()
        raise _invalid()

    ensure_can_sign_in(account)
    credential.failed_attempts = 0
    credential.locked_until = None
    if needs_rehash(credential.password_hash):
        credential.password_hash = hash_secret(password)
    account.last_login_at = _now()
    await session.flush()
    return account, credential


async def change_password(
    session: AsyncSession, email: str, current_password: str, new_password: str
) -> tuple[Account, StaffCredential]:
    account, credential = await authenticate(session, email, current_password)
    if new_password == current_password:
        raise ApiError(422, "WEAK_PASSWORD", "Choose a different password")
    check_password_strength(new_password, account.email)
    credential.password_hash = hash_secret(new_password)
    credential.must_change_password = False
    credential.password_changed_at = _now()
    await session.flush()
    return account, credential


async def create_staff_account(
    session: AsyncSession,
    email: str,
    display_name: str,
    temporary_password: str,
    role: str = "moderator",
) -> Account:
    """Create a moderator (or the admin). They set their own password on first login."""
    if role not in STAFF_ROLES:
        raise ValueError(role)
    email = email.strip().lower()
    if await session.scalar(select(Account.id).where(Account.email == email)):
        raise ApiError(409, "EMAIL_IN_USE", "An account with this email already exists")
    check_password_strength(temporary_password, email)
    account = Account(
        id=uuid.uuid4(), email=email, role=role, status="active", display_name=display_name
    )
    session.add(account)
    await session.flush()
    session.add(
        StaffCredential(
            account_id=account.id,
            password_hash=hash_secret(temporary_password),
            must_change_password=True,
            failed_attempts=0,
        )
    )
    await session.flush()
    return account
