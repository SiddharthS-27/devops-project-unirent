"""The /auth and /admin/moderators routes against PostgreSQL and Redis."""

import uuid

import httpx
import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse

from unirent_security import db
from unirent_security.api import admin_router, auth_router
from unirent_security.config import get_settings
from unirent_security.errors import ApiError
from unirent_security.staff_auth import create_staff_account


@pytest.fixture
async def client(session, monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "ms_auth_mode", "mock")
    monkeypatch.setattr(settings, "phone_auth_mode", "mock")
    monkeypatch.setattr(settings, "environment", "test")
    await db.redis().flushdb()

    app = FastAPI()

    @app.exception_handler(ApiError)
    async def handle(_, exc: ApiError):
        return JSONResponse(
            {"error": {"code": exc.code}}, status_code=exc.status_code, headers=exc.headers
        )

    app.include_router(auth_router)
    app.include_router(admin_router)
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
        yield c
    await db.reset()


def _email() -> str:
    return f"s{uuid.uuid4().hex[:10]}@college.edu"


async def _student(client, email=None):
    email = email or _email()
    id_token = (await client.post("/auth/microsoft/mock-token", json={"email": email})).json()
    r = await client.post("/auth/microsoft", json=id_token)
    assert r.status_code == 200, r.text
    return r.json()


async def test_first_sign_in_creates_a_student(client):
    pair = await _student(client)
    assert pair["account"]["role"] == "student"
    assert pair["expires_in"] == 900
    again = await _student(client, pair["account"]["email"])
    assert again["account"]["id"] == pair["account"]["id"]


async def test_other_domains_cannot_sign_in(client):
    r = await client.post("/auth/microsoft/mock-token", json={"email": "x@gmail.com"})
    r = await client.post("/auth/microsoft", json=r.json())
    assert r.status_code == 403
    assert r.json()["error"]["code"] == "EMAIL_DOMAIN_NOT_ALLOWED"


async def test_refresh_rotates_and_reuse_revokes_the_chain(client):
    pair = await _student(client)
    first = pair["refresh_token"]

    r = await client.post("/auth/refresh", json={"refresh_token": first})
    assert r.status_code == 200
    second = r.json()["refresh_token"]
    assert second != first

    # Replaying the spent token revokes the family...
    r = await client.post("/auth/refresh", json={"refresh_token": first})
    assert r.json()["error"]["code"] == "REFRESH_TOKEN_REUSED"
    # ...so the newest token stops working too.
    r = await client.post("/auth/refresh", json={"refresh_token": second})
    assert r.status_code == 401


async def test_logout_revokes_the_refresh_token(client):
    pair = await _student(client)
    assert (await client.post("/auth/logout", json=pair)).status_code == 204
    r = await client.post("/auth/refresh", json={"refresh_token": pair["refresh_token"]})
    assert r.status_code == 401


async def test_phone_verification_saves_the_number(client):
    pair = await _student(client)
    headers = {"Authorization": f"Bearer {pair['access_token']}"}
    phone = "+91" + str(uuid.uuid4().int)[:10]
    token = await client.post("/auth/phone/mock-token", json={"phone": phone, "code": "123456"})
    r = await client.post("/auth/phone", json=token.json(), headers=headers)
    assert r.status_code == 200
    assert r.json()["phone"] == phone

    other = await _student(client)
    r = await client.post(
        "/auth/phone",
        json=token.json(),
        headers={"Authorization": f"Bearer {other['access_token']}"},
    )
    assert r.json()["error"]["code"] == "PHONE_IN_USE"


async def _moderator(session, email, password="temporary-pass-1"):
    await create_staff_account(session, email, "Mod", password)
    await session.commit()


async def test_staff_first_login_must_change_password(client, session):
    email = _email()
    await _moderator(session, email)
    r = await client.post(
        "/auth/staff/login", json={"email": email, "password": "temporary-pass-1"}
    )
    assert r.json()["account"]["must_change_password"] is True
    r = await client.post(
        "/auth/staff/password",
        json={
            "email": email,
            "current_password": "temporary-pass-1",
            "new_password": "a-much-better-pass",
        },
    )
    assert r.status_code == 200
    assert r.json()["account"]["must_change_password"] is False


async def test_five_wrong_passwords_lock_the_account(client, session):
    email = _email()
    await _moderator(session, email)
    for _ in range(5):
        r = await client.post("/auth/staff/login", json={"email": email, "password": "wrong"})
        assert r.status_code == 401
    # Locked even with the right password; the rate limit also kicks in after five.
    r = await client.post(
        "/auth/staff/login", json={"email": email, "password": "temporary-pass-1"}
    )
    assert r.status_code in (423, 429)
    await db.redis().flushdb()
    r = await client.post(
        "/auth/staff/login", json={"email": email, "password": "temporary-pass-1"}
    )
    assert r.json()["error"]["code"] == "ACCOUNT_LOCKED"


async def test_only_the_admin_manages_moderators(client, session):
    student = await _student(client)
    r = await client.get(
        "/admin/moderators", headers={"Authorization": f"Bearer {student['access_token']}"}
    )
    assert r.status_code == 403

    admin_email = _email()
    await create_staff_account(session, admin_email, "Admin", "admin-password-1", role="admin")
    await session.commit()
    login = await client.post(
        "/auth/staff/login", json={"email": admin_email, "password": "admin-password-1"}
    )
    changed = await client.post(
        "/auth/staff/password",
        json={
            "email": admin_email,
            "current_password": "admin-password-1",
            "new_password": "admin-password-2",
        },
    )
    assert login.status_code == 200
    headers = {"Authorization": f"Bearer {changed.json()['access_token']}"}
    mod_email = _email()
    r = await client.post(
        "/admin/moderators",
        json={"email": mod_email, "name": "New Mod", "temporary_password": "welcome-pass-1"},
        headers=headers,
    )
    assert r.status_code == 201
    mod_id = r.json()["id"]
    r = await client.post(f"/admin/moderators/{mod_id}/deactivate", headers=headers)
    assert r.json()["status"] == "deactivated"
    r = await client.post(
        "/auth/staff/login", json={"email": mod_email, "password": "welcome-pass-1"}
    )
    assert r.json()["error"]["code"] == "ACCOUNT_DEACTIVATED"
