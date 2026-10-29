"""The timer runner. The backend owns every time-based rule; this only notices
when timers are due and asks the backend to fire them. Firing is idempotent on
the backend, so a timer fired twice (say, after a restart) does nothing more."""

import asyncio
import logging

import httpx

from unirent_workers.backend_api import BackendApi
from unirent_workers.metrics import TIMERS_FIRED

log = logging.getLogger(__name__)

INTERVAL_SECONDS = 30.0
BATCH = 100


async def run_once(backend: BackendApi) -> int:
    """Fire every timer that is due now; returns how many fired."""
    fired = 0
    for timer in await backend.due_timers(BATCH):
        try:
            result = await backend.fire_timer(timer["id"])
        except httpx.HTTPError as exc:
            TIMERS_FIRED.labels(kind=timer["kind"], outcome="error").inc()
            log.warning("timer fire failed", extra={"timer": timer["id"], "error": str(exc)})
            continue
        outcome = "fired" if result.get("fired") else "skipped"
        TIMERS_FIRED.labels(kind=timer["kind"], outcome=outcome).inc()
        fired += result.get("fired", False)
    return fired


async def run(backend: BackendApi, stop: asyncio.Event, interval: float = INTERVAL_SECONDS) -> None:
    log.info("timer runner started")
    while not stop.is_set():
        try:
            await run_once(backend)
        except httpx.HTTPError as exc:
            log.warning("timer runner can't reach the api", extra={"error": str(exc)})
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except TimeoutError:
            pass
    log.info("timer runner stopped")
