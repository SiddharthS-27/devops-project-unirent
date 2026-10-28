"""Prometheus metrics for the api, named per the metric list in the plan.

Request latency is recorded by middleware; booking transitions where they
happen; the business gauges are refreshed from the database every 30 seconds.
The security and payments packages register their counters in the same
registry, so /metrics serves them all."""

import asyncio
import logging
import time

from prometheus_client import Counter, Gauge, Histogram
from sqlalchemy import func, select
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.db import get_sessionmaker

log = logging.getLogger(__name__)

REQUEST_DURATION = Histogram(
    "unirent_http_request_duration_seconds",
    "API request latency",
    ["route", "method", "status"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)
BOOKING_TRANSITIONS = Counter(
    "unirent_booking_transitions_total", "Booking state changes", ["from", "to"]
)
OVERDUE_BOOKINGS = Gauge("unirent_overdue_bookings", "Rentals overdue right now")
OPEN_APPEALS = Gauge("unirent_open_appeals", "Appeals waiting for a ruling")
ACTIVE_LISTINGS = Gauge("unirent_active_listings", "Listings visible in search")
BOOKINGS_BY_STATE = Gauge("unirent_bookings", "Bookings by state", ["state"])

REFRESH_SECONDS = 30


class MetricsMiddleware:
    def __init__(self, app: ASGIApp):
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["path"] == "/metrics":
            await self.app(scope, receive, send)
            return
        started = time.perf_counter()
        status = 500

        async def record_status(message: Message) -> None:
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, record_status)
        finally:
            route = getattr(scope.get("route"), "path", None) or "unmatched"
            REQUEST_DURATION.labels(route, scope["method"], str(status)).observe(
                time.perf_counter() - started
            )


async def refresh_gauges() -> None:
    # Imported here: the booking modules import this one for BOOKING_TRANSITIONS.
    from app.modules.bookings.models import Booking
    from app.modules.listings.models import Listing

    async with get_sessionmaker()() as session:
        grouped = select(Booking.status, func.count()).group_by(Booking.status)
        states = dict((await session.execute(grouped)).all())
        active = await session.scalar(select(func.count()).where(Listing.status == "active"))
    for state, count in states.items():
        BOOKINGS_BY_STATE.labels(state).set(count)
    OVERDUE_BOOKINGS.set(states.get("overdue", 0))
    OPEN_APPEALS.set(states.get("in_appeal", 0))
    ACTIVE_LISTINGS.set(active or 0)


async def gauge_loop(stop: asyncio.Event) -> None:
    while not stop.is_set():
        try:
            await refresh_gauges()
        except Exception as exc:  # noqa: BLE001 - metrics must never take the api down
            log.warning("metrics refresh failed", extra={"error": str(exc)})
        try:
            await asyncio.wait_for(stop.wait(), timeout=REFRESH_SECONDS)
        except TimeoutError:
            pass
