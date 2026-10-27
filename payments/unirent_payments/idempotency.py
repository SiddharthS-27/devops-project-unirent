"""Idempotency-Key handling for every request that moves money or changes a booking.

The first response to (account, key) is kept for 24 hours: in Redis for speed and
in payments.idempotency_records so it survives a Redis flush. A repeat gets the
same response back; the same key with a different request is refused with 422.
A repeat that arrives while the first is still running waits for its result."""

import asyncio
import hashlib
import json
import logging
from datetime import UTC, datetime, timedelta

from redis.exceptions import RedisError
from sqlalchemy import delete
from sqlalchemy.dialects.postgresql import insert
from starlette.types import ASGIApp, Message, Receive, Scope, Send
from unirent_security.errors import ApiError
from unirent_security.tokens import decode_access_token

from unirent_payments import db
from unirent_payments.config import get_settings
from unirent_payments.models import IdempotencyRecord

log = logging.getLogger(__name__)

MUTATING = {b"POST", b"PUT", b"PATCH", b"DELETE"}
WAIT_SECONDS = 10.0
LOCK_SECONDS = 30


def _error(status: int, code: str, message: str) -> tuple[int, bytes]:
    return status, json.dumps({"error": {"code": code, "message": message}}).encode()


class IdempotencyMiddleware:
    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["method"].encode() not in MUTATING:
            await self.app(scope, receive, send)
            return
        headers = dict(scope["headers"])
        key = headers.get(b"idempotency-key", b"").decode("latin-1").strip()
        scope_id = _account_scope(headers.get(b"authorization", b"").decode("latin-1"))
        if not key or scope_id is None:
            await self.app(scope, receive, send)
            return

        body, receive = await _buffer_body(receive)
        request_hash = hashlib.sha256(
            scope["method"].encode() + b" " + scope["path"].encode() + b"\n" + body
        ).hexdigest()

        stored = await _lookup(scope_id, key)
        if stored is None and not await _lock(scope_id, key):
            stored = await _wait_for_result(scope_id, key)
            if stored is None:
                await _reply(send, *_error(409, "IDEMPOTENCY_IN_PROGRESS", "Still working on it"))
                return
        if stored is not None:
            if stored["hash"] != request_hash:
                await _reply(
                    send,
                    *_error(422, "IDEMPOTENCY_KEY_REUSED", "This key was used for another request"),
                )
                return
            await _reply(send, stored["status"], stored["body"].encode(), stored["type"], True)
            return

        captured: dict = {"status": 500, "type": None, "chunks": []}

        async def capture(message: Message) -> None:
            if message["type"] == "http.response.start":
                captured["status"] = message["status"]
                for name, value in message.get("headers", []):
                    if name.lower() == b"content-type":
                        captured["type"] = value.decode("latin-1")
            elif message["type"] == "http.response.body":
                captured["chunks"].append(message.get("body", b""))
            await send(message)

        try:
            await self.app(scope, receive, capture)
        finally:
            status = captured["status"]
            # Server errors and rate limits aren't outcomes; let the retry run again.
            if status < 500 and status != 429:
                await _store(
                    scope_id,
                    key,
                    request_hash,
                    status,
                    b"".join(captured["chunks"]),
                    captured["type"],
                )
            await _unlock(scope_id, key)


def _account_scope(authorization: str) -> str | None:
    if not authorization.lower().startswith("bearer "):
        return None
    try:
        return decode_access_token(authorization[7:].strip())["sub"]
    except ApiError:
        return None  # the route itself will answer 401


async def _buffer_body(receive: Receive) -> tuple[bytes, Receive]:
    chunks = []
    more = True
    while more:
        message = await receive()
        chunks.append(message.get("body", b""))
        more = message.get("more_body", False)
    body = b"".join(chunks)
    sent = False

    async def replay() -> Message:
        nonlocal sent
        if not sent:
            sent = True
            return {"type": "http.request", "body": body, "more_body": False}
        return await receive()

    return body, replay


def _redis_key(scope_id: str, key: str) -> str:
    return f"idem:{scope_id}:{key}"


async def _lookup(scope_id: str, key: str) -> dict | None:
    try:
        cached = await db.redis().get(_redis_key(scope_id, key))
        if cached:
            return json.loads(cached)
    except RedisError as exc:
        log.warning("idempotency cache unavailable", extra={"error": str(exc)})
    async with db.sessionmaker()() as session:
        record = await session.get(IdempotencyRecord, (scope_id, key))
        if record is None or record.expires_at < datetime.now(UTC):
            return None
        return {
            "hash": record.request_hash,
            "status": record.status_code,
            "body": record.response_body,
            "type": record.content_type,
        }


async def _lock(scope_id: str, key: str) -> bool:
    try:
        return bool(
            await db.redis().set(f"{_redis_key(scope_id, key)}:lock", "1", nx=True, ex=LOCK_SECONDS)
        )
    except RedisError:
        return True  # the payment's own unique constraints still prevent doubles


async def _unlock(scope_id: str, key: str) -> None:
    try:
        await db.redis().delete(f"{_redis_key(scope_id, key)}:lock")
    except RedisError:
        pass


async def _wait_for_result(scope_id: str, key: str) -> dict | None:
    deadline = asyncio.get_running_loop().time() + WAIT_SECONDS
    while asyncio.get_running_loop().time() < deadline:
        await asyncio.sleep(0.1)
        stored = await _lookup(scope_id, key)
        if stored is not None:
            return stored
    return None


async def _store(
    scope_id: str, key: str, request_hash: str, status: int, body: bytes, content_type: str | None
) -> None:
    ttl = timedelta(hours=get_settings().idempotency_ttl_hours)
    now = datetime.now(UTC)
    text_body = body.decode("utf-8", errors="replace")
    entry = {"hash": request_hash, "status": status, "body": text_body, "type": content_type}
    try:
        await db.redis().set(
            _redis_key(scope_id, key), json.dumps(entry), ex=int(ttl.total_seconds())
        )
    except RedisError as exc:
        log.warning("idempotency cache unavailable", extra={"error": str(exc)})
    async with db.sessionmaker()() as session:
        await session.execute(
            insert(IdempotencyRecord)
            .values(
                scope=scope_id,
                key=key,
                request_hash=request_hash,
                status_code=status,
                response_body=text_body,
                content_type=content_type,
                created_at=now,
                expires_at=now + ttl,
            )
            .on_conflict_do_nothing()
        )
        await session.commit()


async def purge_expired() -> int:
    """Drop records past their 24 hours (run by the nightly job)."""
    async with db.sessionmaker()() as session:
        result = await session.execute(
            delete(IdempotencyRecord).where(IdempotencyRecord.expires_at < datetime.now(UTC))
        )
        await session.commit()
        return result.rowcount or 0


async def _reply(
    send: Send, status: int, body: bytes, content_type: str | None = None, replayed: bool = False
) -> None:
    headers = [(b"content-type", (content_type or "application/json").encode())]
    if replayed:
        headers.append((b"idempotent-replayed", b"true"))
    await send({"type": "http.response.start", "status": status, "headers": headers})
    await send({"type": "http.response.body", "body": body})
