"""Starts payments reconciliation every night at 02:00 IST, for the day before."""

import asyncio
import logging
from datetime import datetime, time, timedelta, timezone

import httpx

from unirent_workers.backend_api import BackendApi

log = logging.getLogger(__name__)

IST = timezone(timedelta(hours=5, minutes=30))
RUN_AT = time(2, 0)
RETRY_AFTER = timedelta(minutes=10)
ATTEMPTS = 3


def next_run(after: datetime) -> datetime:
    """The next 02:00 IST strictly after `after`."""
    local = after.astimezone(IST)
    candidate = datetime.combine(local.date(), RUN_AT, tzinfo=IST)
    if candidate <= local:
        candidate += timedelta(days=1)
    return candidate


async def trigger(backend: BackendApi) -> dict | None:
    for attempt in range(1, ATTEMPTS + 1):
        try:
            result = await backend.run_reconciliation()
            log.info(
                "reconciliation done",
                extra={"run": result.get("id"), "totals": result.get("totals")},
            )
            return result
        except httpx.HTTPError as exc:
            log.warning(
                "reconciliation trigger failed", extra={"attempt": attempt, "error": str(exc)}
            )
            if attempt < ATTEMPTS:
                await asyncio.sleep(RETRY_AFTER.total_seconds())
    return None


async def run(backend: BackendApi, stop: asyncio.Event) -> None:
    log.info("reconciliation trigger started")
    while not stop.is_set():
        due = next_run(datetime.now(IST))
        wait = (due - datetime.now(IST)).total_seconds()
        try:
            await asyncio.wait_for(stop.wait(), timeout=max(wait, 0))
            break  # stopping
        except TimeoutError:
            await trigger(backend)
    log.info("reconciliation trigger stopped")
