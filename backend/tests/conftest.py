import uuid

import httpx
import pytest
import unirent_payments.db
import unirent_security.db
from sqlalchemy import text
from unirent_security.config import get_settings as security_settings

from app.core.db import dispose_engine, get_engine
from app.core.redis import close_redis
from app.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    await close_redis()
    await dispose_engine()
    await unirent_security.db.reset()
    await unirent_payments.db.reset()


@pytest.fixture
async def db_ready():
    """Skip unless PostgreSQL is reachable and migrated."""
    try:
        async with get_engine().connect() as conn:
            await conn.execute(text("SELECT 1 FROM core.profiles LIMIT 1"))
            await conn.execute(text("SELECT 1 FROM security.accounts LIMIT 1"))
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"database unavailable: {exc}")


@pytest.fixture
async def api(client, db_ready, monkeypatch):
    """A client against a migrated database, with mock sign-in."""
    settings = security_settings()
    monkeypatch.setattr(settings, "ms_auth_mode", "mock")
    monkeypatch.setattr(settings, "phone_auth_mode", "mock")
    monkeypatch.setattr(settings, "environment", "test")
    await unirent_security.db.redis().flushdb()
    return client


class Student:
    def __init__(self, client: httpx.AsyncClient, pair: dict):
        self.client = client
        self.id = uuid.UUID(pair["account"]["id"])
        self.email = pair["account"]["email"]
        self.headers = {"Authorization": f"Bearer {pair['access_token']}"}

    async def get(self, path, **kw):
        return await self.client.get("/api/v1" + path, headers=self.headers, **kw)

    async def post(self, path, **kw):
        headers = {**self.headers, **kw.pop("headers", {})}
        return await self.client.post("/api/v1" + path, headers=headers, **kw)

    async def put(self, path, **kw):
        return await self.client.put("/api/v1" + path, headers=self.headers, **kw)

    async def patch(self, path, **kw):
        return await self.client.patch("/api/v1" + path, headers=self.headers, **kw)

    async def delete(self, path, **kw):
        return await self.client.delete("/api/v1" + path, headers=self.headers, **kw)


PROFILE = {
    "full_name": "Asha Rao",
    "roll_number": "CS21B001",
    "department": "Computer Science",
    "year": 3,
    "residence_type": "hostel",
    "hostel_name": "Ganga",
    "room_number": "214",
}


async def sign_in(client) -> Student:
    email = f"s{uuid.uuid4().hex[:10]}@college.edu"
    r = await client.post("/api/v1/auth/microsoft/mock-token", json={"email": email})
    r = await client.post("/api/v1/auth/microsoft", json=r.json())
    assert r.status_code == 200, r.text
    return Student(client, r.json())


async def onboard(client, profile=None) -> Student:
    """A student who has finished onboarding."""
    student = await sign_in(client)
    r = await student.put("/me/profile", json=profile or PROFILE)
    assert r.status_code == 200, r.text
    phone = "+91" + str(uuid.uuid4().int)[:10]
    token = await client.post(
        "/api/v1/auth/phone/mock-token", json={"phone": phone, "code": "123456"}
    )
    assert (await student.post("/auth/phone", json=token.json())).status_code == 200
    r = await student.post("/me/terms", json={"version": "2026-10"})
    assert r.json()["onboarding"]["complete"] is True
    return student
