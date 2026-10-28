import json
import uuid

import pytest
from sqlalchemy import select, text

from tests.conftest import FakeProducer
from unirent_workers import db
from unirent_workers.consumers.base import Consumer
from unirent_workers.models import DeadLetter


@pytest.fixture
async def workers_db(session):
    try:
        await session.execute(text("SELECT 1 FROM workers.processed_events LIMIT 1"))
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"workers schema not migrated: {exc}")
    yield
    await db.dispose()


def _event() -> bytes:
    return json.dumps(
        {"event_id": str(uuid.uuid4()), "type": "BookingRequested", "payload": {}}
    ).encode()


def _consumer(handler, producer=None) -> Consumer:
    consumer = Consumer(f"test-{uuid.uuid4().hex[:6]}", ["bookings.events"], handler, producer)
    consumer.backoff = (0, 0)
    return consumer


async def test_a_redelivered_event_is_handled_once(workers_db):
    calls = []

    async def handler(event):
        calls.append(event["event_id"])

    consumer = _consumer(handler)
    raw = _event()
    assert await consumer.process("bookings.events", raw) == "ok"
    assert await consumer.process("bookings.events", raw) == "duplicate"
    assert len(calls) == 1


async def test_flaky_handlers_are_retried_in_process(workers_db):
    attempts = []

    async def handler(event):
        attempts.append(1)
        if len(attempts) < 3:
            raise RuntimeError("blip")

    assert await _consumer(handler).process("bookings.events", _event()) == "ok"
    assert len(attempts) == 3


async def test_failures_go_to_retry_then_dead_letter(workers_db, session):
    async def handler(event):
        raise RuntimeError("always broken")

    producer = FakeProducer()
    consumer = _consumer(handler, producer)
    raw = _event()
    assert await consumer.process("bookings.events", raw) == "retry"
    assert producer.sent[-1][0] == "bookings.events.retry"
    assert await consumer.process("bookings.events.retry", raw) == "dead_lettered"
    assert producer.sent[-1][0] == "bookings.events.dlq"
    event_id = json.loads(raw)["event_id"]
    letter = await session.scalar(select(DeadLetter).where(DeadLetter.event_id == event_id))
    assert letter is not None and "always broken" in letter.error
    # Settled: a redelivery of the dead-lettered event is skipped.
    assert await consumer.process("bookings.events.retry", raw) == "duplicate"
