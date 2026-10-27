"""A Kafka consumer that hands each event to a handler."""

import asyncio
import json
import logging
from collections.abc import Awaitable, Callable

from aiokafka import AIOKafkaConsumer

from unirent_workers.config import get_settings
from unirent_workers.metrics import EVENTS_PROCESSED

log = logging.getLogger(__name__)

Handler = Callable[[dict], Awaitable[None]]


class Consumer:
    def __init__(self, name: str, topics: list[str], handler: Handler):
        self.name = name
        self.topics = topics
        self.handler = handler

    async def process(self, topic: str, raw: bytes) -> str:
        event = json.loads(raw)
        try:
            await self.handler(event)
        except Exception:  # noqa: BLE001
            log.exception(
                "handler failed", extra={"consumer": self.name, "type": event.get("type")}
            )
            EVENTS_PROCESSED.labels(consumer=self.name, outcome="failed").inc()
            return "failed"
        EVENTS_PROCESSED.labels(consumer=self.name, outcome="ok").inc()
        return "ok"

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
                        await self.process(message.topic, message.value)
                if batches:
                    await consumer.commit()
        finally:
            await consumer.stop()
            log.info("consumer stopped", extra={"consumer": self.name})
