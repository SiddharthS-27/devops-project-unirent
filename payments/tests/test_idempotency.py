import asyncio
import itertools
import uuid

import httpx
import pytest
from fastapi import FastAPI
from unirent_security.models import Account
from unirent_security.tokens import issue_access_token

from unirent_payments import db
from unirent_payments.idempotency import IdempotencyMiddleware

calls = itertools.count()


def _app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(IdempotencyMiddleware)

    @app.post("/do")
    async def do(body: dict):
        await asyncio.sleep(0.05)
        return {"call": next(calls), "echo": body}

    return app


@pytest.fixture
async def client(session):
    transport = httpx.ASGITransport(app=_app())
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
        yield c
    await db.reset()


def _auth() -> dict:
    account = Account(id=uuid.uuid4(), email="a@college.edu", role="student", status="active")
    return {"Authorization": f"Bearer {issue_access_token(account)}"}


async def test_repeat_returns_the_first_response(client):
    headers = {**_auth(), "Idempotency-Key": uuid.uuid4().hex}
    first = await client.post("/do", json={"a": 1}, headers=headers)
    again = await client.post("/do", json={"a": 1}, headers=headers)
    assert again.json() == first.json()
    assert again.headers["idempotent-replayed"] == "true"


async def test_same_key_different_body_is_refused(client):
    headers = {**_auth(), "Idempotency-Key": uuid.uuid4().hex}
    await client.post("/do", json={"a": 1}, headers=headers)
    r = await client.post("/do", json={"a": 2}, headers=headers)
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"


async def test_concurrent_repeats_run_once(client):
    headers = {**_auth(), "Idempotency-Key": uuid.uuid4().hex}
    results = await asyncio.gather(
        *(client.post("/do", json={"a": 1}, headers=headers) for _ in range(5))
    )
    assert len({r.json()["call"] for r in results}) == 1


async def test_keys_are_per_account(client):
    key = uuid.uuid4().hex
    a = await client.post("/do", json={"a": 1}, headers={**_auth(), "Idempotency-Key": key})
    b = await client.post("/do", json={"a": 1}, headers={**_auth(), "Idempotency-Key": key})
    assert a.json()["call"] != b.json()["call"]


async def test_survives_a_redis_flush(client):
    headers = {**_auth(), "Idempotency-Key": uuid.uuid4().hex}
    first = await client.post("/do", json={"a": 1}, headers=headers)
    await db.redis().flushdb()
    again = await client.post("/do", json={"a": 1}, headers=headers)
    assert again.json() == first.json()
