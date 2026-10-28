"""Run the workers. Each component is a task; SIGTERM stops them all cleanly."""

import asyncio
import logging
import signal
import sys

from prometheus_client import start_http_server

from unirent_workers import db, logs, migrate, relay, timers
from unirent_workers.backend_api import BackendApi
from unirent_workers.config import get_settings
from unirent_workers.consumers import matcher
from unirent_workers.consumers import push as push_consumer
from unirent_workers.consumers.base import Consumer
from unirent_workers.kafka import start_producer
from unirent_workers.push import PushDelivery, make_sender

log = logging.getLogger("unirent.workers")
COMPONENTS = ("relay", "push", "timers", "matcher")


async def main(components: list[str]) -> None:
    settings = get_settings()
    logs.configure(settings.log_level)
    start_http_server(settings.metrics_port)
    await asyncio.to_thread(migrate.upgrade)

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)

    backend = BackendApi()
    producer = await start_producer()
    tasks = []
    if "relay" in components:
        tasks.append(asyncio.create_task(relay.run(producer, stop), name="relay"))
    delivery = PushDelivery(backend, make_sender())
    if "push" in components:
        handler = push_consumer.make_handler(delivery)
        consumer = Consumer("push", push_consumer.PUSH_TOPICS, handler, producer)
        tasks.append(asyncio.create_task(consumer.run(stop), name="push"))
    if "matcher" in components:
        handler = matcher.make_handler(backend, delivery)
        consumer = Consumer("matcher", matcher.MATCHER_TOPICS, handler, producer)
        tasks.append(asyncio.create_task(consumer.run(stop), name="matcher"))

    if "timers" in components:
        tasks.append(asyncio.create_task(timers.run(backend, stop), name="timers"))

    log.info("workers running", extra={"components": components})
    await stop.wait()
    log.info("stopping")
    await asyncio.gather(*tasks, return_exceptions=True)
    await producer.stop()
    await backend.aclose()
    await db.dispose()


def run() -> None:
    components = sys.argv[1:] or list(COMPONENTS)
    unknown = set(components) - set(COMPONENTS)
    if unknown:
        sys.exit(f"unknown components: {', '.join(sorted(unknown))}")
    asyncio.run(main(components))


if __name__ == "__main__":
    run()
