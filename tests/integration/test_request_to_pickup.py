"""Request, approval and pickup across backend, payments and the simulator."""

import time

import pytest

from fixtures.client import sim
from fixtures.data import (
    approved_booking,
    hand_over,
    listing,
    onboarded,
    owner,
    pay_upi,
    period,
    pickup_photos,
)

pytestmark = pytest.mark.bookings


def test_upi_pickup_makes_the_rental_active():
    lister, renter, booking = approved_booking()
    bid = booking["id"]
    pickup_photos(lister, renter, bid)
    paid = pay_upi(renter, bid)
    seen = renter.ok("GET", f"/bookings/{bid}")
    assert [p["status"] for p in seen["payments"]] == ["captured"]
    assert seen["next_action"]["key"] == "show_otp"
    active = hand_over(lister, renter, bid)
    assert active["status"] == "active"
    assert paid["payment"]["amount_paise"] == booking["amount_paise"]


def test_cash_pickup_waits_for_the_owner_to_mark_it():
    lister, renter, booking = approved_booking()
    bid = booking["id"]
    pickup_photos(lister, renter, bid)
    payment = renter.ok("POST", f"/bookings/{bid}/pickup/payment", json={"method": "cash"})
    assert renter.post(f"/bookings/{bid}/pickup/otp").json()["error"]["code"] == "STEP_LOCKED"
    lister.ok("POST", f"/payments/{payment['id']}/mark-cash-paid")
    assert hand_over(lister, renter, bid)["status"] == "active"


def test_failed_upi_lets_the_renter_retry():
    lister, renter, booking = approved_booking()
    bid = booking["id"]
    pickup_photos(lister, renter, bid)
    pay_upi(renter, bid, outcome="failed")
    time.sleep(1.5)  # the simulator's failure webhook
    retry = pay_upi(renter, bid)
    assert renter.ok("GET", f"/payments/{retry['payment']['id']}")["status"] == "captured"


def test_withdraw_and_decline_release_the_request():
    lister = owner()
    item = listing(lister)
    a, b = onboarded(), onboarded()
    first = a.ok("POST", "/bookings", 201, json={"listing_id": item["id"], **period()})
    second = b.ok("POST", "/bookings", 201, json={"listing_id": item["id"], **period(48)})
    assert a.ok("POST", f"/bookings/{first['id']}/withdraw")["status"] == "withdrawn"
    declined = lister.ok("POST", f"/bookings/{second['id']}/decline", json={"reason": "Away"})
    assert declined["status"] == "declined"


def test_cancel_before_payment_with_a_note():
    lister, renter, booking = approved_booking()
    out = lister.ok("POST", f"/bookings/{booking['id']}/cancel", json={"note": "It broke"})
    assert out["status"] == "cancelled"
    seen = renter.ok("GET", f"/bookings/{booking['id']}")
    assert seen["cancellation"]["note"] == "It broke" and seen["cancellation"]["rating_due"]


def test_sale_handover():
    lister, buyer, booking = approved_booking(
        kind="sale", sale_price_paise=250000, price_per_day_paise=None, price_per_hour_paise=None
    )
    pickup_photos(lister, buyer, booking["id"])
    pay_upi(buyer, booking["id"])
    assert hand_over(lister, buyer, booking["id"])["status"] == "awaiting_reviews"


def test_simulator_received_signed_webhooks():
    with sim() as s:
        captured = s.get("/sim/webhooks", params={"event": "payment.captured"}).json()
    assert captured and all(200 in w["deliveries"] for w in captured[-3:])
