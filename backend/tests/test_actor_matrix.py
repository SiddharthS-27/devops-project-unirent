"""Every booking action, tried by every kind of caller. The allowed actor
succeeds; the other side gets 403; strangers get 404 (they can't tell the
booking exists); staff can read but not act on the students' behalf."""

import pytest

from tests.conftest import (
    approved_booking,
    moderator,
    onboard,
    pay_cash_and_hand_over,
    pickup_photos,
)
from tests.test_booking_requests import _request

pytestmark = pytest.mark.bookings


async def _cast(api, stage: str):
    """Owner, renter, stranger, moderator and a booking at `stage`."""
    if stage == "requested":
        from tests.conftest import create_listing, lister

        owner = await lister(api)
        listing = await create_listing(owner)
        renter = await onboard(api)
        booking = (await _request(renter, listing)).json()
    else:
        owner, renter, booking = await approved_booking(api)
        if stage == "active":
            await pickup_photos(owner, renter, booking["id"])
            booking = await pay_cash_and_hand_over(owner, renter, booking["id"])
    return {
        "owner": owner,
        "renter": renter,
        "stranger": await onboard(api),
        "staff": await moderator(api),
    }, booking


# (stage, action path, body, the one actor allowed)
ACTIONS = [
    ("requested", "approve", None, "owner"),
    ("requested", "decline", {}, "owner"),
    ("requested", "withdraw", None, "renter"),
    ("approved", "cancel", {"note": "Plans changed"}, "both"),
    ("approved", "pickup/otp", None, "renter"),
    ("active", "return/start", None, "renter"),
    ("active", "extensions", {"new_end_at": "2099-01-01T00:00:00+00:00"}, "renter"),
    ("active", "escalate", {}, "owner"),
]

DENIED = {"owner": 403, "renter": 403, "stranger": 404, "staff": 403}


@pytest.mark.parametrize("stage, action, body, allowed", ACTIONS)
async def test_only_the_right_actor_can(api, stage, action, body, allowed):
    cast, booking = await _cast(api, stage)
    path = f"/bookings/{booking['id']}/{action}"
    for name in ("stranger", "staff", "owner", "renter"):
        if allowed in (name, "both"):
            continue
        r = await cast[name].post(path, json=body)
        assert r.status_code == DENIED[name], (name, r.text)
        assert r.json()["error"]["code"] != "BOOKING_STATE", name


@pytest.mark.parametrize("stage", ["requested", "approved", "active"])
async def test_reading_a_booking(api, stage):
    cast, booking = await _cast(api, stage)
    path = f"/bookings/{booking['id']}"
    for name, status in {"owner": 200, "renter": 200, "staff": 200, "stranger": 404}.items():
        assert (await cast[name].get(path)).status_code == status, name
    assert (await cast["staff"].get(path)).json()["role"] == "staff"
