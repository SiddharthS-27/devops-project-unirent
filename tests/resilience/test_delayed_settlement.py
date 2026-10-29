"""Delayed settlement processing: webhooks that arrive late, out of order or
never, and reconciliation afterwards. No payment is lost or doubled, and the
ledger still matches Razorpay."""

import time

import pytest

from fixtures.client import admin, sim
from fixtures.data import approved_booking, pickup_photos

pytestmark = [pytest.mark.payments, pytest.mark.reconciliation]


def _start_upi():
    lister, renter, booking = approved_booking()
    pickup_photos(lister, renter, booking["id"])
    payment = renter.ok("POST", f"/bookings/{booking['id']}/pickup/payment", json={"method": "upi"})
    return renter, booking, payment


def _status(user, payment_id):
    return user.ok("GET", f"/payments/{payment_id}")["status"]


def _mismatches_for(payment_id: str) -> list:
    report = admin().ok("POST", "/admin/reconciliation/run", json={})
    return [m for m in report["mismatches"] if m["payment_id"] == payment_id]


def test_late_webhook_alone_captures_the_payment():
    """The payer closed the app before verify; the webhook arrives seconds later."""
    renter, booking, payment = _start_upi()
    with sim() as s:
        s.post(
            f"/sim/orders/{payment['checkout']['order_id']}/pay",
            json={"webhooks": "late", "delay_seconds": 2},
        )
    assert _status(renter, payment["id"]) == "pending"
    time.sleep(4)
    assert _status(renter, payment["id"]) == "captured"
    assert _mismatches_for(payment["id"]) == []


def test_missing_webhook_is_covered_by_verify():
    renter, booking, payment = _start_upi()
    with sim() as s:
        checkout = s.post(
            f"/sim/orders/{payment['checkout']['order_id']}/pay", json={"webhooks": "none"}
        ).json()
    renter.ok("POST", f"/payments/{payment['id']}/verify", json=checkout)
    assert _status(renter, payment["id"]) == "captured"
    assert _mismatches_for(payment["id"]) == []


def test_transfer_before_capture_is_harmless():
    """Razorpay may deliver transfer.processed before payment.captured."""
    renter, booking, payment = _start_upi()
    with sim() as s:
        s.post("/sim/webhooks/pause")
        checkout = s.post(f"/sim/orders/{payment['checkout']['order_id']}/pay", json={}).json()
        s.post("/sim/webhooks/pause", params={"paused": False})
        hooks = [
            h
            for h in s.get("/sim/webhooks").json()
            if checkout["razorpay_payment_id"] in str(h["event"])
        ]
        for hook in sorted(hooks, key=lambda h: h["event"]["event"] != "transfer.processed"):
            s.post(f"/sim/webhooks/{hook['id']}/replay")
    assert _status(renter, payment["id"]) == "captured"
    renter.ok("POST", f"/payments/{payment['id']}/verify", json=checkout)  # a late verify: no-op
    assert _mismatches_for(payment["id"]) == []


def test_a_storm_of_duplicate_deliveries_captures_once():
    renter, booking, payment = _start_upi()
    with sim() as s:
        s.post(f"/sim/orders/{payment['checkout']['order_id']}/pay", json={"webhooks": "twice"})
        captured = [
            h
            for h in s.get("/sim/webhooks", params={"event": "payment.captured"}).json()
            if h["event"]["payload"]["payment"]["entity"]["order_id"]
            == payment["checkout"]["order_id"]
        ]
        for _ in range(5):
            s.post(f"/sim/webhooks/{captured[0]['id']}/replay")
    time.sleep(1)
    seen = renter.ok("GET", f"/bookings/{booking['id']}")
    assert [p["status"] for p in seen["payments"]] == ["captured"]
    assert _mismatches_for(payment["id"]) == []
