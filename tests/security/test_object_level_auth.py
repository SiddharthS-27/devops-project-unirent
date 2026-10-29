"""Broken object-level authorization: every route that takes an ID, called by
someone it doesn't belong to. Strangers must get 404 (or 403 where the object
is public but the action isn't theirs), never the object or a state change."""

import pytest

from fixtures.client import User
from fixtures.data import approved_booking, listing, onboarded, owner, pickup_photos

pytestmark = pytest.mark.security


@pytest.fixture(scope="module")
def world():
    lister, renter, booking = approved_booking()
    pickup_photos(lister, renter, booking["id"])
    payment = renter.ok(
        "POST", f"/bookings/{booking['id']}/pickup/payment", json={"method": "cash"}
    )
    other_listing = listing(owner())
    saved = renter.ok("POST", "/saved-searches", 201, json={"q": "guitar"})
    return {
        "lister": lister,
        "renter": renter,
        "stranger": onboarded("Mallory"),
        "booking": booking["id"],
        "listing": booking["listing"]["id"],
        "payment": payment["id"],
        "other_listing": other_listing["id"],
        "saved": saved["id"],
    }


CASES = [
    # (method, path template, body)
    ("GET", "/bookings/{booking}", None),
    ("POST", "/bookings/{booking}/approve", None),
    ("POST", "/bookings/{booking}/decline", {}),
    ("POST", "/bookings/{booking}/withdraw", None),
    ("POST", "/bookings/{booking}/cancel", {"note": "Not mine to cancel"}),
    ("POST", "/bookings/{booking}/pickup/photos", {"object_keys": ["listing/x/y.jpg"]}),
    ("POST", "/bookings/{booking}/pickup/payment", {"method": "cash"}),
    ("POST", "/bookings/{booking}/pickup/otp", None),
    ("POST", "/bookings/{booking}/pickup/otp/verify", {"code": "123456"}),
    ("POST", "/bookings/{booking}/return/start", None),
    ("POST", "/bookings/{booking}/damage-charge", {"amount_paise": 100, "description": "Mine"}),
    ("POST", "/bookings/{booking}/proceed", None),
    ("POST", "/bookings/{booking}/escalate", {}),
    ("GET", "/bookings/{booking}/review-form", None),
    ("POST", "/bookings/{booking}/reviews", {"ratings": {"communication": 5}, "comment": "Hi"}),
    ("GET", "/payments/{payment}", None),
    ("POST", "/payments/{payment}/mark-cash-paid", None),
    (
        "POST",
        "/payments/{payment}/verify",
        {"razorpay_order_id": "o", "razorpay_payment_id": "p", "razorpay_signature": "s"},
    ),
    ("PATCH", "/listings/{listing}", {"title": "Hijacked listing"}),
    ("POST", "/listings/{listing}/pause", None),
    ("POST", "/listings/{listing}/photos", {"object_key": "listing/x/y.jpg"}),
    ("DELETE", "/saved-searches/{saved}", None),
]


@pytest.mark.parametrize("method, template, body", CASES)
def test_strangers_cannot_touch_other_peoples_objects(world, method, template, body):
    stranger: User = world["stranger"]
    path = template.format(**world)
    r = (
        stranger.request(method, path, json=body)
        if body is not None
        else stranger.request(method, path)
    )
    assert r.status_code in (403, 404), f"{method} {path} -> {r.status_code} {r.text}"
    assert world["booking"] not in r.text or r.status_code == 404


def test_nothing_changed(world):
    booking = world["renter"].ok("GET", f"/bookings/{world['booking']}")
    assert booking["status"] == "approved"
    assert [p["status"] for p in booking["payments"]] == ["pending"]
    listing = world["lister"].ok("GET", f"/listings/{world['listing']}")
    assert listing["title"] != "Hijacked listing"


def test_the_other_side_cannot_act_for_you(world):
    """The renter can't mark their own cash as received, or approve as the owner."""
    renter: User = world["renter"]
    assert renter.post(f"/payments/{world['payment']}/mark-cash-paid").status_code == 404
    assert renter.patch(f"/listings/{world['listing']}", json={"title": "Mine"}).status_code == 404
