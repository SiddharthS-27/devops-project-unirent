from datetime import datetime, timedelta

from app.core.config import get_settings
from tests.test_rental import active_rental, time_travel  # noqa: F401 - fixture

SERVICE = {"X-Service-Token": get_settings().service_token}


async def _due(api, booking_id):
    """This booking's due timers. Other tests leave due timers behind, so read the
    booking's own rows rather than the runner's oldest-first page."""
    from sqlalchemy import select

    from app.core.clock import now
    from app.core.db import get_sessionmaker
    from app.core.models import Timer

    async with get_sessionmaker()() as session:
        rows = await session.scalars(
            select(Timer).where(
                Timer.ref_id == booking_id,
                Timer.fired_at.is_(None),
                Timer.cancelled_at.is_(None),
                Timer.due_at <= now(),
            )
        )
        return [{"id": str(t.id), "kind": t.kind} for t in rows]


async def test_overdue_fires_through_the_internal_api_once(api, time_travel):  # noqa: F811
    owner, renter, booking = await active_rental(api)
    end = datetime.fromisoformat(booking["end_at"])
    from app.core import clock

    time_travel(end - clock.now() + timedelta(minutes=31))
    due = await _due(api, booking["id"])
    kinds = {t["kind"] for t in due}
    assert {"overdue_start", "return_reminder"} <= kinds
    overdue = next(t for t in due if t["kind"] == "overdue_start")

    first = (await api.post(f"/internal/timers/{overdue['id']}/fire", headers=SERVICE)).json()
    again = (await api.post(f"/internal/timers/{overdue['id']}/fire", headers=SERVICE)).json()
    assert first == {"fired": True, "outcome": "applied"}
    assert again["fired"] is False
    assert (await renter.get(f"/bookings/{booking['id']}")).json()["status"] == "overdue"

    # The reminder is stale by now: firing it does nothing to the booking.
    reminder = next(t for t in due if t["kind"] == "return_reminder")
    r = (await api.post(f"/internal/timers/{reminder['id']}/fire", headers=SERVICE)).json()
    assert r == {"fired": True, "outcome": "nothing_to_do"}


async def test_unanswered_request_expires(api, time_travel):  # noqa: F811
    from tests.conftest import create_listing, lister, onboard
    from tests.test_booking_requests import _request

    owner = await lister(api)
    listing = await create_listing(owner)
    renter = await onboard(api)
    booking = (await _request(renter, listing)).json()
    time_travel(timedelta(hours=24, minutes=1))
    [expiry] = [t for t in await _due(api, booking["id"]) if t["kind"] == "request_expiry"]
    await api.post(f"/internal/timers/{expiry['id']}/fire", headers=SERVICE)
    assert (await renter.get(f"/bookings/{booking['id']}")).json()["status"] == "expired"


async def test_due_lists_oldest_first(api):
    r = await api.get("/internal/timers/due", params={"limit": 5}, headers=SERVICE)
    due = [t["due_at"] for t in r.json()["timers"]]
    assert due == sorted(due) and len(due) <= 5
