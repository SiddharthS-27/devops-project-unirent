import time

import jwt
import pytest

from unirent_security.config import get_settings
from unirent_security.errors import ApiError
from unirent_security.microsoft import ISSUER, mock_id_token, verify_id_token


@pytest.fixture(autouse=True)
def mock_mode(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "ms_auth_mode", "mock")
    monkeypatch.setattr(settings, "ms_allowed_domain", "college.edu")
    monkeypatch.setattr(settings, "environment", "test")


def _token(**overrides):
    settings = get_settings()
    now = int(time.time())
    claims = {
        "aud": settings.ms_client_id,
        "iss": ISSUER.format(tenant=settings.ms_tenant_id),
        "tid": settings.ms_tenant_id,
        "oid": "oid-1",
        "email": "a@college.edu",
        "iat": now,
        "exp": now + 600,
    }
    claims.update(overrides)
    return jwt.encode(claims, settings.mock_token_secret, algorithm="HS256")


async def test_valid_token_gives_identity():
    identity = await verify_id_token(mock_id_token("Asha@College.edu", "Asha"))
    assert identity.email == "asha@college.edu"
    assert identity.name == "Asha"


@pytest.mark.parametrize(
    "overrides, code",
    [
        ({"tid": "other-tenant"}, "WRONG_TENANT"),
        ({"email": "a@gmail.com", "preferred_username": None}, "EMAIL_DOMAIN_NOT_ALLOWED"),
        ({"email": "a@evilcollege.edu"}, "EMAIL_DOMAIN_NOT_ALLOWED"),
        ({"aud": "someone-else"}, "INVALID_ID_TOKEN"),
        ({"iss": "https://evil.example/v2.0"}, "INVALID_ID_TOKEN"),
        ({"exp": int(time.time()) - 3600}, "ID_TOKEN_EXPIRED"),
        ({"oid": None}, "INVALID_ID_TOKEN"),
    ],
)
async def test_bad_tokens_are_refused(overrides, code):
    with pytest.raises(ApiError) as err:
        await verify_id_token(_token(**overrides))
    assert err.value.code == code


async def test_wrong_signature_is_refused():
    token = jwt.encode({"aud": "x"}, "not-the-secret-but-long-enough-0123", algorithm="HS256")
    with pytest.raises(ApiError) as err:
        await verify_id_token(token)
    assert err.value.code == "INVALID_ID_TOKEN"


async def test_mock_mode_is_refused_in_staging(monkeypatch):
    monkeypatch.setattr(get_settings(), "environment", "staging")
    with pytest.raises(ApiError) as err:
        await verify_id_token(mock_id_token("a@college.edu"))
    assert err.value.code == "MOCK_AUTH_DISABLED"
