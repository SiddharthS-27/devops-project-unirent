"""Rate limits hold against header spoofing, fresh tokens and parallel clients."""

import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest

from fixtures.client import admin, raw
from fixtures.data import approved_booking, onboarded, pickup_photos

pytestmark = pytest.mark.security


def test_staff_login_limit_ignores_forwarded_headers():
    """Spoofed X-Forwarded-For doesn't reset the per-account limit."""
    email = f"nobody{uuid.uuid4().hex[:6]}@unirent.in"
    codes = []
    with raw() as http:
        for n in range(8):
            r = http.post(
                "/api/v1/auth/staff/login",
                json={"email": email, "password": "wrong-password"},
                headers={"X-Forwarded-For": f"10.0.0.{n}", "X-Real-IP": f"10.0.1.{n}"},
            )
            codes.append(r.status_code)
    assert codes[:5] == [401] * 5
    assert set(codes[5:]) == {429}


def test_payment_start_limit_survives_token_rotation():
    """New access tokens for the same account share one payment-start budget."""
    lister, renter, booking = approved_booking()
    pickup_photos(lister, renter, booking["id"])
    path = f"/bookings/{booking['id']}/pickup/payment"
    codes = []
    for n in range(14):
        if n % 4 == 3:  # rotate tokens part way through
            with raw() as http:
                pair = http.post(
                    "/api/v1/auth/refresh", json={"refresh_token": renter.tokens["refresh_token"]}
                ).json()
            renter.tokens = pair
        method = "upi" if n % 2 else "cash"  # switching method forces a new payment start
        codes.append(renter.post(path, json={"method": method}).status_code)
    assert 429 in codes, codes


def test_chatbot_limit_with_parallel_clients():
    student = onboarded()
    with ThreadPoolExecutor(10) as pool:
        codes = list(
            pool.map(
                lambda n: student.post("/help/chat", json={"message": f"late fee {n}"}).status_code,
                range(30),
            )
        )
    assert codes.count(200) == 20 and codes.count(429) == 10


def test_otp_entry_is_limited_per_code():
    from fixtures.data import hand_over  # noqa: F401 - documents the normal path

    lister, renter, booking = approved_booking()
    bid = booking["id"]
    pickup_photos(lister, renter, bid)
    payment = renter.ok("POST", f"/bookings/{bid}/pickup/payment", json={"method": "cash"})
    lister.ok("POST", f"/payments/{payment['id']}/mark-cash-paid")
    code = renter.ok("POST", f"/bookings/{bid}/pickup/otp")["code"]
    wrong = "000000" if code != "000000" else "111111"
    codes = [
        lister.post(f"/bookings/{bid}/pickup/otp/verify", json={"code": wrong}).json()["error"][
            "code"
        ]
        for _ in range(6)
    ]
    assert codes == ["WRONG_CODE"] * 5 + ["RATE_LIMITED"]
    # Even the right code is refused once this code's tries are used up.
    r = lister.post(f"/bookings/{bid}/pickup/otp/verify", json={"code": code})
    assert r.json()["error"]["code"] == "RATE_LIMITED"
    assert admin()  # the admin session is still usable after the noise
