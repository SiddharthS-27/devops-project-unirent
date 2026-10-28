"""The relay and a consumer against the real broker (skipped without Kafka)."""

import asyncio
import json
import uuid

import pytest
from aiokafka import AIOKafkaConsumer
from sqlalchemy import text

from unirent_workers import db
from unirent_workers.config import get_settings
from unirent_workers.consumers.base import Consumer
from unirent_workers.kafka import start_producer
from unirent_workers.relay import relay_once


@pytest.fixture
async def producer(session):
    try:
        p = await asyncio.wait_for(start_producer(), timeout=5)
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"kafka unavailable: {exc}")
    yield p
    await p.stop()
    await db.dispose()


async def test_an_outbox_event_reaches_a_consumer_once(producer, session):
    aggregate = str(uuid.uuid4())
    event_id = uuid.uuid4()
    await session.execute(
        text(
            "INSERT INTO core.outbox (id, topic, type, version, aggregate_id, payload, producer, "
            "occurred_at) VALUES (:id, 'listings.events', 'ListingPublished', 1, :agg, "
            "CAST('{}' AS jsonb), 'backend', now())"
        ),
        {"id": event_id, "agg": aggregate},
    )
    await session.commit()
    while await relay_once(producer, "core", batch_size=500):
        pass

    reader = AIOKafkaConsumer(
        "listings.events",
        bootstrap_servers=get_settings().kafka_bootstrap,
        group_id=f"test-{uuid.uuid4().hex[:8]}",
        auto_offset_reset="earliest",
    )
    await reader.start()
    try:
        found = None
        deadline = asyncio.get_running_loop().time() + 20
        while found is None and asyncio.get_running_loop().time() < deadline:
            batches = await reader.getmany(timeout_ms=1000)
            for messages in batches.values():
                for message in messages:
                    if json.loads(message.value)["event_id"] == str(event_id):
                        found = message
    finally:
        await reader.stop()
    assert found is not None and found.key == aggregate.encode()

    handled = []

    async def handler(event):
        handled.append(event["event_id"])

    consumer = Consumer(f"test-{uuid.uuid4().hex[:6]}", ["listings.events"], handler)
    assert await consumer.process(found.topic, found.value) == "ok"
    assert await consumer.process(found.topic, found.value) == "duplicate"
    assert handled == [str(event_id)]
