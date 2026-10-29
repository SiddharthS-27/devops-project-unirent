"""A Kafka consumer with idempotent handling, retries and dead letters.

Each event is skipped if this consumer already processed its event_id. A failing
handler is retried in-process with backoff; if it still fails the event goes to
the topic's .retry companion, handled again after a delay; a second failure
sends it to .dlq and the dead_letters table. Offsets are committed only after
an event is settled, so a crash re-delivers rather than loses it."""

import asyncio
import json
import logging
import time
from collections.abc import Awaitable, Callable

from aiokafka import AIOKafkaConsumer
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from unirent_workers import db, topics
from unirent_workers.config import get_settings
from unirent_workers.kafka import encode
from unirent_workers.metrics import DLQ_MESSAGES, EVENT_RETRIES, EVENTS_PROCESSED
from unirent_workers.models import DeadLetter, ProcessedEvent

log = logging.getLogger(__name__)

Handler = Callable[[dict], Awaitable[None]]
BACKOFF_SECONDS = (0.5, 1.0, 2.0)


class Consumer:
    def __init__(self, name: str, base_topics: list[str], handler: Handler, producer=None):
        self.name = name
        self.base_topics = base_topics
        self.topics = base_topics + [topics.retry_topic(t) for t in base_topics]
        self.handler = handler
        self.producer = producer
        self.backoff = BACKOFF_SECONDS[: get_settings().consumer_attempts - 1]

    async def _seen(self, event_id: str) -> bool:
        async with db.sessionmaker()() as session:
            found = await session.scalar(
                select(ProcessedEvent.event_id).where(
                    ProcessedEvent.consumer == self.name, ProcessedEvent.event_id == event_id
                )
            )
        return found is not None

    async def _settle(self, event_id: str, outcome: str) -> None:
        async with db.sessionmaker()() as session:
            await session.execute(
                insert(ProcessedEvent)
                .values(consumer=self.name, event_id=event_id, outcome=outcome)
                .on_conflict_do_nothing()
            )
            await session.commit()

    async def _handle_with_retries(self, event: dict) -> Exception | None:
        for attempt, delay in enumerate((*self.backoff, None)):
            try:
                await self.handler(event)
                return None
            except Exception as exc:  # noqa: BLE001 - every failure is retried, then dead-lettered
                if delay is None:
                    return exc
                EVENT_RETRIES.labels(consumer=self.name).inc()
                log.warning(
                    "handler failed, retrying",
                    extra={"consumer": self.name, "attempt": attempt + 1, "error": str(exc)},
                )
                await asyncio.sleep(delay)
        return None

    async def _forward(self, topic: str, event: dict, key: bytes | None) -> None:
        if self.producer is not None:
            await self.producer.send_and_wait(topic, encode(event), key=key)

    async def process(self, topic: str, raw: bytes, key: bytes | None = None) -> str:
        event = json.loads(raw)
        event_id = event.get("event_id")
        if event_id and await self._seen(event_id):
            EVENTS_PROCESSED.labels(consumer=self.name, outcome="duplicate").inc()
            return "duplicate"
        error = await self._handle_with_retries(event)
        if error is None:
            outcome = "ok"
        elif topic.endswith(".retry"):
            outcome = "dead_lettered"
            dlq = topics.dlq_topic(topic)
            await self._forward(dlq, event, key)
            async with db.sessionmaker()() as session:
                session.add(
                    DeadLetter(
                        consumer=self.name,
                        topic=topics.base_of(topic),
                        event_id=event_id,
                        type=event.get("type"),
                        payload=event,
                        error=str(error)[:2000],
                    )
                )
                await session.commit()
            DLQ_MESSAGES.labels(topic=dlq).inc()
            log.error("event dead-lettered", extra={"consumer": self.name, "event_id": event_id})
        else:
            await self._forward(topics.retry_topic(topic), event, key)
            EVENTS_PROCESSED.labels(consumer=self.name, outcome="retry").inc()
            return "retry"  # not settled: the .retry copy decides its fate
        if event_id:
            await self._settle(event_id, outcome)
        EVENTS_PROCESSED.labels(consumer=self.name, outcome=outcome).inc()
        return outcome

    async def _wait_for_retry(self, timestamp_ms: int, stop: asyncio.Event) -> None:
        due = timestamp_ms / 1000 + get_settings().retry_delay_seconds
        remaining = due - time.time()
        if remaining > 0:
            try:
                await asyncio.wait_for(stop.wait(), timeout=remaining)
            except TimeoutError:
                pass

    async def run(self, stop: asyncio.Event) -> None:
        consumer = AIOKafkaConsumer(
            *self.topics,
            bootstrap_servers=get_settings().kafka_bootstrap,
            group_id=f"unirent-{self.name}",
            enable_auto_commit=False,
            auto_offset_reset="earliest",
        )
        await consumer.start()
        log.info("consumer started", extra={"consumer": self.name, "topics": self.topics})
        try:
            while not stop.is_set():
                batches = await consumer.getmany(timeout_ms=500, max_records=50)
                for messages in batches.values():
                    for message in messages:
                        if message.topic.endswith(".retry"):
                            await self._wait_for_retry(message.timestamp, stop)
                            if stop.is_set():
                                return  # uncommitted: redelivered after restart
                        await self.process(message.topic, message.value, message.key)
                if batches:
                    await consumer.commit()
        finally:
            await consumer.stop()
            log.info("consumer stopped", extra={"consumer": self.name})
