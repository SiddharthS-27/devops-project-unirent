"""UniRent tokens. Access tokens are 15-minute JWTs. Refresh tokens are random
strings, stored hashed, rotated on every use; presenting a spent one means it
leaked, so the whole family from that sign-in is revoked."""

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security.config import get_settings
from unirent_security.errors import unauthenticated
from unirent_security.models import Account, RefreshToken

ALGORITHM = "HS256"


def _now() -> datetime:
    return datetime.now(UTC)


def hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def issue_access_token(account: Account, must_change_password: bool = False) -> str:
    settings = get_settings()
    now = _now()
    claims: dict[str, Any] = {
        "sub": str(account.id),
        "role": account.role,
        "status": account.status,
        "iss": settings.jwt_issuer,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=settings.access_token_ttl_seconds)).timestamp()),
        "jti": uuid.uuid4().hex,
        "typ": "access",
    }
    if must_change_password:
        claims["pwd_change"] = True
    return jwt.encode(claims, settings.jwt_secret, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    try:
        claims = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[ALGORITHM],
            issuer=settings.jwt_issuer,
            options={"require": ["exp", "sub", "role", "status"]},
        )
    except jwt.ExpiredSignatureError:
        raise unauthenticated("TOKEN_EXPIRED", "The access token has expired") from None
    except jwt.PyJWTError:
        raise unauthenticated("INVALID_TOKEN", "The access token is not valid") from None
    if claims.get("typ") != "access":
        raise unauthenticated("INVALID_TOKEN", "The access token is not valid")
    return claims


async def issue_refresh_token(
    session: AsyncSession, account_id: uuid.UUID, family_id: uuid.UUID | None = None
) -> tuple[str, RefreshToken]:
    raw = secrets.token_urlsafe(48)
    now = _now()
    row = RefreshToken(
        id=uuid.uuid4(),
        account_id=account_id,
        family_id=family_id or uuid.uuid4(),
        token_hash=hash_token(raw),
        issued_at=now,
        expires_at=now + timedelta(days=get_settings().refresh_token_ttl_days),
    )
    session.add(row)
    await session.flush()
    return raw, row


async def revoke_family(session: AsyncSession, family_id: uuid.UUID) -> None:
    await session.execute(
        update(RefreshToken)
        .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=_now())
    )


async def revoke_all(session: AsyncSession, account_id: uuid.UUID) -> None:
    await session.execute(
        update(RefreshToken)
        .where(RefreshToken.account_id == account_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=_now())
    )


async def rotate_refresh_token(session: AsyncSession, raw: str) -> tuple[Account, str]:
    """Spend a refresh token and return the account with its replacement.
    Commits on reuse, so the family stays revoked although an error is raised."""
    row = await session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_token(raw)).with_for_update()
    )
    if row is None or row.revoked_at is not None:
        raise unauthenticated("INVALID_REFRESH_TOKEN", "Sign in again")
    if row.used_at is not None:
        await revoke_family(session, row.family_id)
        await session.commit()
        raise unauthenticated("REFRESH_TOKEN_REUSED", "Sign in again")
    if row.expires_at <= _now():
        raise unauthenticated("REFRESH_TOKEN_EXPIRED", "Sign in again")

    account = await session.get(Account, row.account_id)
    if account is None or account.status in ("banned", "deactivated"):
        await revoke_family(session, row.family_id)
        await session.commit()
        raise unauthenticated("ACCOUNT_DISABLED", "This account can't sign in")

    new_raw, new_row = await issue_refresh_token(session, account.id, row.family_id)
    row.used_at = _now()
    row.replaced_by = new_row.id
    return account, new_raw


async def revoke_refresh_token(session: AsyncSession, raw: str) -> None:
    """Sign out: revoke the family the token belongs to. Unknown tokens are ignored."""
    row = await session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_token(raw))
    )
    if row is not None:
        await revoke_family(session, row.family_id)
