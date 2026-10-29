from datetime import datetime, timedelta

import pytest

from app.core import clock
from app.core.db import get_sessionmaker
from app.modules.bookings import rental
from app.modules.bookings.models import Booking
from tests.conftest import approved_booking, pay_cash_and_hand_over, pickup_photos


@pytest.fixture
def time_travel():
    """Move the app's clock; always put it back."""

    def jump(delta: timedelta) -> None:
        clock.set_offset(clock.get_offset() + delta)

    yield jump
    clock.set_offset(timedelta(0))


async def active_rental(api):
    owner, renter, booking = await approved_booking(api)
    await pickup_photos(owner, renter, booking["id"])
    active = await pay_cash_and_hand_over(owner, renter, booking["id"])
    assert active["status"] == "active"
    return owner, renter, active


async def _run(fn, booking_id):
    async with get_sessionmaker()() as session:
        booking = await session.get(Booking, booking_id, with_for_update=True)
        result = await fn(session, booking)
        await session.commit()
        return result


async def test_extension_moves_the_end_and_costs_the_rate(api):
    owner, renter, booking = await active_rental(api)
    end = datetime.fromisoformat(booking["end_at"])
    new_end = (end + timedelta(hours=5)).isoformat()
    ext = (
        await renter.post(f"/bookings/{booking['id']}/extensions", json={"new_end_at": new_end})
    ).json()
    assert ext["status"] == "requested" and ext["amount_paise"] == 5 * 2000
    assert (await owner.get(f"/bookings/{booking['id']}")).json()["next_action"][
        "key"
    ] == "decide_extension"

    r = await owner.post(f"/bookings/{booking['id']}/extensions/{ext['id']}/approve")
    assert r.json()["status"] == "approved"
    seen = (await renter.get(f"/bookings/{booking['id']}")).json()
    assert seen["end_at"] == datetime.fromisoformat(new_end).isoformat().replace(
        "+00:00", "Z"
    ) or seen["end_at"].startswith(new_end[:16])
    assert seen["next_action"]["key"] == "pay_extension"

    r = await renter.post(
        f"/bookings/{booking['id']}/extensions/{ext['id']}/payment", json={"method": "cash"}
    )
    assert r.json()["pay_in_cash_at_return"] is True
    seen = (await renter.get(f"/bookings/{booking['id']}")).json()
    assert seen["charges"]["cash_extensions_paise"] == 10000


async def test_overdue_after_grace_with_a_growing_late_fee(api, time_travel):
    owner, renter, booking = await active_rental(api)
    end = datetime.fromisoformat(booking["end_at"])
    time_travel(end - clock.now() + timedelta(minutes=20))  # inside the 30-minute grace
    assert await _run(rental.mark_overdue, booking["id"]) is False

    time_travel(timedelta(minutes=15))  # 35 minutes late
    assert await _run(rental.mark_overdue, booking["id"]) is True
    seen = (await renter.get(f"/bookings/{booking['id']}")).json()
    assert seen["status"] == "overdue" and seen["next_action"]["key"] == "return_now"
    assert seen["charges"]["late_fee_paise"] == 1000  # base fee only

    r = await owner.post(f"/bookings/{booking['id']}/escalate", json={})
    assert r.json()["error"]["code"] == "ESCALATION_NOT_YET"
    time_travel(timedelta(hours=2))  # 2h35m late: base + 2 full hours of 2%
    rent = seen["amount_paise"]
    seen = (await owner.get(f"/bookings/{booking['id']}")).json()
    assert seen["charges"]["late_fee_paise"] == round((1000 + rent * 2 * 2 // 100) / 100) * 100
    assert seen["can_escalate"]
    r = await owner.post(f"/bookings/{booking['id']}/escalate", json={"note": "Not answering"})
    assert r.status_code == 200 and not r.json()["can_escalate"]


async def test_overdue_found_late_counts_from_end_plus_grace(api, time_travel):
    # The demo jumps the clock straight past the grace: the timer fires late,
    # but escalation still opens an hour after the rental became overdue.
    owner, renter, booking = await active_rental(api)
    end = datetime.fromisoformat(booking["end_at"])
    time_travel(end - clock.now() + timedelta(hours=2, minutes=30))
    assert await _run(rental.mark_overdue, booking["id"]) is True
    seen = (await owner.get(f"/bookings/{booking['id']}")).json()
    assert datetime.fromisoformat(seen["overdue_since"]) == end + timedelta(minutes=30)
    assert seen["can_escalate"]
