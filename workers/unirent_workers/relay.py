"""The outbox relay: publish committed events, in order, exactly as written.

Each outbox row is published to its topic keyed by aggregate_id, then marked
sent. A row is only marked after Kafka acknowledged it, so a crash or a Kafka
outage never loses an event; it can at worst publish one twice, which the
consumers drop by event_id."""

import asyncio
import logging
from typing import Protocol

from sqlalchemy import text

from unirent_workers import db
from unirent_workers.config import get_settings
from unirent_workers.kafka import encode
from unirent_workers.metrics import EVENTS_RELAYED, OUTBOX_BACKLOG

log = logging.getLogger(__name__)

SOURCES = ("core", "payments")


class Producer(Protocol):
    async def send_and_wait(self, topic: str, value: bytes, key: bytes): ...


def envelope(row) -> dict:
    return {
        "event_id": str(row.id),
        "type": row.type,
        "version": row.version,
        "occurred_at": row.occurred_at.isoformat(),
        "producer": row.producer,
        "aggregate_id": row.aggregate_id,
        "payload": row.payload,
    }


async def relay_once(producer: Producer, source: str, batch_size: int | None = None) -> int:
    """Publish one batch from `<source>.outbox`; returns how many were sent."""
    batch_size = batch_size or get_settings().relay_batch_size
    async with db.sessionmaker()() as session:
        rows = (
            await session.execute(
                text(
                    "SELECT id, topic, type, version, aggregate_id, payload, producer, "
                    f"occurred_at FROM {source}.outbox WHERE sent_at IS NULL "
                    f"ORDER BY occurred_at, id LIMIT :limit FOR UPDATE SKIP LOCKED"
                ),
                {"limit": batch_size},
            )
        ).all()
        sent = []
        error = None
        for row in rows:
            try:
                await producer.send_and_wait(
                    row.topic, encode(envelope(row)), key=row.aggregate_id.encode()
                )
            except Exception as exc:  # noqa: BLE001 - stop here; later rows keep their order
                error = exc
                await session.execute(
                    text(
                        f"UPDATE {source}.outbox SET attempts = attempts + 1, last_error = :err "
                        f"WHERE id = :id"
                    ),
                    {"id": row.id, "err": str(exc)[:500]},
                )
                break
            sent.append(row.id)
        if sent:
            await session.execute(
                text(
                    f"UPDATE {source}.outbox SET sent_at = now(), attempts = attempts + 1 "
                    f"WHERE id = ANY(:ids)"
                ),
                {"ids": sent},
            )
        await session.commit()
    EVENTS_RELAYED.labels(source=source).inc(len(sent))
    if error is not None:
        log.warning("publish failed", extra={"source": source, "error": str(error)})
    return len(sent)


async def backlog(source: str) -> int:
    async with db.sessionmaker()() as session:
        count = await session.scalar(
            text(f"SELECT count(*) FROM {source}.outbox WHERE sent_at IS NULL")
        )
    OUTBOX_BACKLOG.labels(source=source).set(count or 0)
    return count or 0


async def run(producer: Producer, stop: asyncio.Event) -> None:
    interval = get_settings().relay_interval_seconds
    log.info("relay started")
    while not stop.is_set():
        busy = False
        for source in SOURCES:
            try:
                busy |= await relay_once(producer, source) > 0
                await backlog(source)
            except Exception:  # noqa: BLE001 - keep relaying the other source
                log.exception("relay batch failed", extra={"source": source})
        if not busy:
            try:
                await asyncio.wait_for(stop.wait(), timeout=interval)
            except TimeoutError:
                pass
    log.info("relay stopped")
