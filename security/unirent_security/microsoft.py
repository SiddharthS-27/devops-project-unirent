"""Microsoft Entra ID sign-in. The app runs the PKCE flow and sends us the ID
token; we check it ourselves and never store Microsoft's tokens."""

import time
import uuid
from dataclasses import dataclass
from typing import Any

import httpx
import jwt

from unirent_security.config import SecuritySettings, get_settings
from unirent_security.errors import ApiError, unauthenticated

KEYS_URL = "https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys"
ISSUER = "https://login.microsoftonline.com/{tenant}/v2.0"
LEEWAY_SECONDS = 60
KEYS_TTL_SECONDS = 6 * 3600


@dataclass(frozen=True)
class MicrosoftIdentity:
    oid: str
    email: str
    name: str | None


class _KeyCache:
    """Microsoft's signing keys, refreshed every few hours or on an unknown key ID."""

    def __init__(self) -> None:
        self._keys: dict[str, Any] = {}
        self._fetched_at = 0.0

    async def get(self, kid: str, tenant: str) -> Any:
        stale = time.monotonic() - self._fetched_at > KEYS_TTL_SECONDS
        if stale or kid not in self._keys:
            await self._refresh(tenant)
        try:
            return self._keys[kid]
        except KeyError:
            raise unauthenticated("INVALID_ID_TOKEN", "Unknown signing key") from None

    async def _refresh(self, tenant: str) -> None:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(KEYS_URL.format(tenant=tenant))
            response.raise_for_status()
        keys = {}
        for jwk in response.json()["keys"]:
            keys[jwk["kid"]] = jwt.PyJWK(jwk).key
        self._keys = keys
        self._fetched_at = time.monotonic()


_keys = _KeyCache()


def _claims_to_identity(claims: dict[str, Any], settings: SecuritySettings) -> MicrosoftIdentity:
    if claims.get("tid") != settings.ms_tenant_id:
        raise ApiError(403, "WRONG_TENANT", "Sign in with your college Microsoft account")
    email = (claims.get("email") or claims.get("preferred_username") or "").strip().lower()
    domain = settings.ms_allowed_domain.lower()
    if not email.endswith("@" + domain):
        raise ApiError(403, "EMAIL_DOMAIN_NOT_ALLOWED", f"Only @{domain} accounts can sign in")
    oid = claims.get("oid")
    if not oid:
        raise unauthenticated("INVALID_ID_TOKEN", "The ID token has no object ID")
    return MicrosoftIdentity(oid=oid, email=email, name=claims.get("name"))


def _decode_options(settings: SecuritySettings) -> dict[str, Any]:
    return {
        "audience": settings.ms_client_id,
        "issuer": ISSUER.format(tenant=settings.ms_tenant_id),
        "leeway": LEEWAY_SECONDS,
        "options": {"require": ["exp", "iat", "aud", "iss"]},
    }


async def verify_id_token(id_token: str) -> MicrosoftIdentity:
    """Check signature, audience, issuer, tenant and email domain."""
    settings = get_settings()
    try:
        if settings.ms_auth_mode == "mock":
            if not settings.mock_allowed():
                raise ApiError(500, "MOCK_AUTH_DISABLED", "Mock sign-in is off here")
            claims = jwt.decode(
                id_token,
                settings.mock_token_secret,
                algorithms=["HS256"],
                **_decode_options(settings),
            )
        else:
            header = jwt.get_unverified_header(id_token)
            key = await _keys.get(header.get("kid", ""), settings.ms_tenant_id)
            claims = jwt.decode(id_token, key, algorithms=["RS256"], **_decode_options(settings))
    except jwt.ExpiredSignatureError:
        raise unauthenticated("ID_TOKEN_EXPIRED", "Sign in with Microsoft again") from None
    except jwt.PyJWTError as exc:
        raise unauthenticated("INVALID_ID_TOKEN", f"The ID token is not valid: {exc}") from None
    return _claims_to_identity(claims, settings)


def mock_id_token(email: str, name: str | None = None, oid: str | None = None) -> str:
    """A Microsoft-shaped ID token signed with the mock key, for dev and tests."""
    settings = get_settings()
    now = int(time.time())
    claims = {
        "aud": settings.ms_client_id,
        "iss": ISSUER.format(tenant=settings.ms_tenant_id),
        "tid": settings.ms_tenant_id,
        "oid": oid or str(uuid.uuid5(uuid.NAMESPACE_URL, "mock-oid:" + email.lower())),
        "email": email,
        "name": name or email.split("@")[0],
        "iat": now,
        "nbf": now,
        "exp": now + 3600,
    }
    return jwt.encode(claims, settings.mock_token_secret, algorithm="HS256")
