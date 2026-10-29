"""Phone verification. The app proves the number with Firebase Phone
Authentication and sends us Firebase's ID token; we only save numbers we have
seen in a token we verified."""

import time
import uuid
from datetime import UTC, datetime
from typing import Any

import httpx
import jwt
from cryptography.x509 import load_pem_x509_certificate
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security.config import get_settings
from unirent_security.errors import ApiError, not_found
from unirent_security.models import Account

CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
)
ISSUER = "https://securetoken.google.com/{project}"
CERTS_TTL_SECONDS = 3600
MOCK_CODE = "123456"

_certs: dict[str, Any] = {}
_certs_fetched_at = 0.0


async def _public_key(kid: str) -> Any:
    global _certs, _certs_fetched_at
    if kid not in _certs or time.monotonic() - _certs_fetched_at > CERTS_TTL_SECONDS:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(CERTS_URL)
            response.raise_for_status()
        _certs = {
            key_id: load_pem_x509_certificate(pem.encode()).public_key()
            for key_id, pem in response.json().items()
        }
        _certs_fetched_at = time.monotonic()
    try:
        return _certs[kid]
    except KeyError:
        raise ApiError(401, "INVALID_PHONE_TOKEN", "Unknown signing key") from None


async def verify_firebase_token(id_token: str) -> str:
    """Return the verified phone number (E.164) from a Firebase ID token."""
    settings = get_settings()
    options = {
        "audience": settings.firebase_project_id,
        "issuer": ISSUER.format(project=settings.firebase_project_id),
        "leeway": 60,
        "options": {"require": ["exp", "iat", "aud", "iss", "sub"]},
    }
    try:
        if settings.phone_auth_mode == "mock":
            if not settings.mock_allowed():
                raise ApiError(500, "MOCK_AUTH_DISABLED", "Mock phone sign-in is off here")
            secret = settings.mock_token_secret
            claims = jwt.decode(id_token, secret, algorithms=["HS256"], **options)
        else:
            kid = jwt.get_unverified_header(id_token).get("kid", "")
            claims = jwt.decode(id_token, await _public_key(kid), algorithms=["RS256"], **options)
    except jwt.PyJWTError as exc:
        raise ApiError(401, "INVALID_PHONE_TOKEN", f"The phone token is not valid: {exc}") from None
    phone = claims.get("phone_number")
    if not phone or not phone.startswith("+"):
        raise ApiError(422, "PHONE_NOT_VERIFIED", "The token carries no verified phone number")
    return phone


def mock_firebase_token(phone: str, code: str) -> str:
    """Development only: what Firebase would return after the user typed `code`."""
    if code != MOCK_CODE:
        raise ApiError(400, "WRONG_CODE", "That code is not right")
    settings = get_settings()
    now = int(time.time())
    claims = {
        "aud": settings.firebase_project_id,
        "iss": ISSUER.format(project=settings.firebase_project_id),
        "sub": uuid.uuid5(uuid.NAMESPACE_URL, "mock-phone:" + phone).hex,
        "phone_number": phone,
        "iat": now,
        "auth_time": now,
        "exp": now + 3600,
    }
    return jwt.encode(claims, settings.mock_token_secret, algorithm="HS256")


async def save_verified_phone(session: AsyncSession, account_id: uuid.UUID, phone: str) -> Account:
    """Changing the number later goes through the same verification."""
    clash = await session.scalar(
        select(Account.id).where(Account.phone == phone, Account.id != account_id)
    )
    if clash is not None:
        raise ApiError(409, "PHONE_IN_USE", "This number belongs to another account")
    account = await session.get(Account, account_id)
    if account is None:
        raise not_found("Account")
    account.phone = phone
    account.phone_verified_at = datetime.now(UTC)
    await session.flush()
    return account
