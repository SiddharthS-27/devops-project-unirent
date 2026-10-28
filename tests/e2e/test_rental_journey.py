"""A whole rental, the way two students do it on their phones."""

from datetime import datetime, timedelta

import pytest

from fixtures.data import (
    approved_booking,
    hand_over,
    pay_upi,
    pickup_photos,
    upload,
)

pytestmark = pytest.mark.bookings


def _photos(user, bid, phase):
    return user.post(
        f"/bookings/{bid}/{phase}/photos", json={"object_keys": [upload(user, "handover")]}
    )


def test_rental_from_request_to_reviews_with_extension_damage_and_upi():
    lister, renter, booking = approved_booking()
    bid = booking["id"]

    # Pickup: photos, UPI through Checkout, the renter's code.
    pickup_photos(lister, renter, bid)
    pay_upi(renter, bid)
    active = hand_over(lister, renter, bid)
    assert active["status"] == "active"
    assert active["next_action"]["key"] == "rental_active"  # the owner's view
    assert renter.ok("GET", f"/bookings/{bid}")["next_action"]["key"] == "return_on_time"

    # More time: requested, approved, paid by UPI.
    new_end = (datetime.fromisoformat(active["end_at"]) + timedelta(hours=3)).isoformat()
    ext = renter.ok("POST", f"/bookings/{bid}/extensions", 201, json={"new_end_at": new_end})
    lister.ok("POST", f"/bookings/{bid}/extensions/{ext['id']}/approve")
    paid = pay_upi(renter, bid, path=f"extensions/{ext['id']}/payment")
    assert paid["checkout"]["razorpay_signature"]
    seen = renter.ok("GET", f"/bookings/{bid}")
    assert datetime.fromisoformat(seen["end_at"]) == datetime.fromisoformat(new_end)
    assert seen["extensions"][0]["payment"]["status"] == "captured"

    # Return: renter's photos, the owner's inspection, the owner's code.
    renter.ok("POST", f"/bookings/{bid}/return/start")
    assert _photos(lister, bid, "return").json()["error"]["code"] == "STEP_LOCKED"
    assert _photos(renter, bid, "return").status_code == 200
    assert _photos(lister, bid, "return").status_code == 200
    code = lister.ok("POST", f"/bookings/{bid}/return/otp")["code"]
    back = renter.ok("POST", f"/bookings/{bid}/return/otp/verify", json={"code": code})
    assert back["charges"]["late_fee_paise"] == 0  # returned on time

    # An agreed damage charge, paid by UPI, then Proceed.
    lister.ok(
        "POST",
        f"/bookings/{bid}/damage-charge",
        json={"amount_paise": 15000, "description": "Strap torn"},
    )
    assert lister.post(f"/bookings/{bid}/proceed").json()["error"]["code"] == "CHARGES_UNPAID"
    pay_upi(renter, bid, path="return/payment")
    done = lister.ok("POST", f"/bookings/{bid}/proceed")
    assert done["status"] == "awaiting_reviews"

    purposes = sorted((p["purpose"], p["status"]) for p in done["payments"])
    assert purposes == [
        ("extension", "captured"),
        ("rent", "captured"),
        ("return_charges", "captured"),
    ]


def test_rental_paid_in_cash_returned_without_charges():
    lister, renter, booking = approved_booking()
    bid = booking["id"]
    pickup_photos(lister, renter, bid)
    payment = renter.ok("POST", f"/bookings/{bid}/pickup/payment", json={"method": "cash"})
    lister.ok("POST", f"/payments/{payment['id']}/mark-cash-paid")
    hand_over(lister, renter, bid)

    renter.ok("POST", f"/bookings/{bid}/return/start")
    _photos(renter, bid, "return")
    _photos(lister, bid, "return")
    code = lister.ok("POST", f"/bookings/{bid}/return/otp")["code"]
    back = renter.ok("POST", f"/bookings/{bid}/return/otp/verify", json={"code": code})
    assert back["charges"]["total_paise"] == 0 and back["charges"]["paid"]
    assert lister.ok("POST", f"/bookings/{bid}/proceed")["status"] == "awaiting_reviews"
