import uuid

from sqlalchemy import text

from tests.conftest import FakeProducer
from unirent_workers import topics
from unirent_workers.relay import relay_once


async def _outbox(session, n: int, aggregate: str) -> list[uuid.UUID]:
    ids = []
    for i in range(n):
        event_id = uuid.uuid4()
        await session.execute(
            text(
                "INSERT INTO core.outbox (id, topic, type, version, aggregate_id, payload, "
                "producer, occurred_at) VALUES (:id, 'bookings.events', 'BookingRequested', 1, "
                ":agg, CAST(:payload AS jsonb), 'backend', now() + make_interval(secs => :i))"
            ),
            {"id": event_id, "agg": aggregate, "payload": f'{{"n": {i}}}', "i": i},
        )
        ids.append(event_id)
    await session.commit()
    return ids


async def _drain(producer) -> None:
    while await relay_once(producer, "core", batch_size=500):
        pass


async def test_relay_publishes_in_order_with_the_envelope(session):
    aggregate = str(uuid.uuid4())
    ids = await _outbox(session, 3, aggregate)
    producer = FakeProducer()
    await _drain(producer)
    mine = [(t, v, k) for t, v, k in producer.sent if v["aggregate_id"] == aggregate]
    assert [v["event_id"] for _, v, _ in mine] == [str(i) for i in ids]
    topic, value, key = mine[0]
    assert topic == "bookings.events" and key == aggregate.encode()
    assert set(value) == {
        "event_id",
        "type",
        "version",
        "occurred_at",
        "producer",
        "aggregate_id",
        "payload",
    }
    unsent = await session.scalar(
        text("SELECT count(*) FROM core.outbox WHERE aggregate_id = :a AND sent_at IS NULL"),
        {"a": aggregate},
    )
    assert unsent == 0


async def test_a_broker_failure_keeps_the_rest_unsent(session):
    await _drain(FakeProducer())  # clear anything left from other tests
    aggregate = str(uuid.uuid4())
    await _outbox(session, 3, aggregate)
    assert await relay_once(FakeProducer(fail_on=1), "core") == 1
    remaining = await session.scalar(
        text("SELECT count(*) FROM core.outbox WHERE aggregate_id = :a AND sent_at IS NULL"),
        {"a": aggregate},
    )
    assert remaining == 2
    producer = FakeProducer()
    await _drain(producer)
    assert [v["payload"]["n"] for _, v, _ in producer.sent if v["aggregate_id"] == aggregate] == [
        1,
        2,
    ]


def test_every_topic_has_retry_and_dlq():
    assert "bookings.events.retry" in topics.all_topics()
    assert "payments.events.dlq" in topics.all_topics()
    assert topics.base_of("listings.events.retry") == "listings.events"
