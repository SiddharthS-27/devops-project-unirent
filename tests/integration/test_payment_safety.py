"""The PPT's payment and reservation tests: duplicates, concurrency, webhooks."""

import time
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest

from fixtures.client import sim
from fixtures.data import approved_booking, listing, onboarded, owner, period, pickup_photos

pytestmark = pytest.mark.payments


def _ready_to_pay():
    lister, renter, booking = approved_booking()
    pickup_photos(lister, renter, booking["id"])
    return lister, renter, booking


def test_same_key_sequentially_and_concurrently_creates_one_payment():
    _, renter, booking = _ready_to_pay()
    path = f"/bookings/{booking['id']}/pickup/payment"
    key = uuid.uuid4().hex
    first = renter.ok("POST", path, json={"method": "upi"}, key=key)
    again = renter.ok("POST", path, json={"method": "upi"}, key=key)
    assert again == first
    with ThreadPoolExecutor(8) as pool:
        results = list(
            pool.map(lambda _: renter.post(path, json={"method": "upi"}, key=key), range(8))
        )
    assert {r.json()["id"] for r in results} == {first["id"]}
    # A different key for the same pending payment still returns it, not a second charge.
    other = renter.ok("POST", path, json={"method": "upi"})
    assert other["id"] == first["id"]


def test_key_reused_for_a_different_request_is_refused():
    _, renter, booking = _ready_to_pay()
    path = f"/bookings/{booking['id']}/pickup/payment"
    key = uuid.uuid4().hex
    renter.ok("POST", path, json={"method": "upi"}, key=key)
    r = renter.post(path, json={"method": "cash"}, key=key)
    assert r.status_code == 422 and r.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"


def test_concurrent_approvals_of_overlapping_requests_one_wins():
    lister = owner()
    item = listing(lister)
    slot = period(hours_ahead=30, hours=10)
    renters = [onboarded() for _ in range(4)]
    requests = [
        r.ok("POST", "/bookings", 201, json={"listing_id": item["id"], **slot}) for r in renters
    ]
    with ThreadPoolExecutor(4) as pool:
        results = list(pool.map(lambda b: lister.post(f"/bookings/{b['id']}/approve"), requests))
    statuses = sorted(r.status_code for r in results)
    assert statuses.count(200) == 1, [r.text for r in results]
    final = [lister.ok("GET", f"/bookings/{b['id']}")["status"] for b in requests]
    assert final.count("approved") == 1 and final.count("declined") == 3


def test_webhook_replay_and_bad_signature():
    _, renter, booking = _ready_to_pay()
    payment = renter.ok("POST", f"/bookings/{booking['id']}/pickup/payment", json={"method": "upi"})
    with sim() as s:
        s.post(f"/sim/orders/{payment['checkout']['order_id']}/pay", json={"webhooks": "twice"})
        captured = [
            w
            for w in s.get("/sim/webhooks", params={"event": "payment.captured"}).json()
            if w["event"]["payload"]["payment"]["entity"]["order_id"]
            == payment["checkout"]["order_id"]
        ]
        replay = s.post(f"/sim/webhooks/{captured[0]['id']}/replay").json()
        forged = s.post(
            "/sim/webhooks/send", json={"event": captured[0]["event"], "bad_signature": True}
        ).json()
    time.sleep(1)
    assert 200 in replay["deliveries"]
    assert forged["deliveries"][0] == 400
    seen = renter.ok("GET", f"/bookings/{booking['id']}")
    assert [p["status"] for p in seen["payments"]] == ["captured"]


def test_webhook_before_verify_still_captures_once():
    _, renter, booking = _ready_to_pay()
    payment = renter.ok("POST", f"/bookings/{booking['id']}/pickup/payment", json={"method": "upi"})
    with sim() as s:
        checkout = s.post(f"/sim/orders/{payment['checkout']['order_id']}/pay", json={}).json()
    time.sleep(1)  # webhook lands first
    verified = renter.ok("POST", f"/payments/{payment['id']}/verify", json=checkout)
    assert verified["status"] == "captured"
