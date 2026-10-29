from tests.conftest import approved_booking, pay_cash_and_hand_over, pickup_photos


async def test_pickup_steps_unlock_in_order(api):
    owner, renter, booking = await approved_booking(api)
    bid = booking["id"]
    assert booking["next_action"]["key"] == "upload_pickup_photos"

    r = await renter.post(f"/bookings/{bid}/pickup/payment", json={"method": "cash"})
    assert r.json()["error"]["code"] == "STEP_LOCKED"
    await pickup_photos(owner, renter, bid)

    seen = (await renter.get(f"/bookings/{bid}")).json()
    assert seen["next_action"]["key"] == "pay"
    assert (await renter.post(f"/bookings/{bid}/pickup/otp")).json()["error"][
        "code"
    ] == "STEP_LOCKED"

    payment = (await renter.post(f"/bookings/{bid}/pickup/payment", json={"method": "cash"})).json()
    assert payment["status"] == "pending" and payment["amount_paise"] == booking["amount_paise"]
    assert (await owner.get(f"/bookings/{bid}")).json()["next_action"][
        "key"
    ] == "mark_cash_received"
    r = await renter.post(f"/payments/{payment['id']}/mark-cash-paid")
    assert r.status_code == 404  # only the payee marks cash
    await owner.post(f"/payments/{payment['id']}/mark-cash-paid")

    assert (await renter.get(f"/bookings/{bid}")).json()["next_action"]["key"] == "show_otp"
    code = (await renter.post(f"/bookings/{bid}/pickup/otp")).json()["code"]
    assert len(code) == 6
    r = await renter.post(f"/bookings/{bid}/pickup/otp/verify", json={"code": code})
    assert r.status_code == 403  # the owner types the renter's code
    active = (await owner.post(f"/bookings/{bid}/pickup/otp/verify", json={"code": code})).json()
    assert active["status"] == "active"
    assert active["pickup"]["otp_verified_at"]
    assert not active["can_cancel"]


async def test_wrong_codes_are_limited(api):
    owner, renter, booking = await approved_booking(api)
    bid = booking["id"]
    await pickup_photos(owner, renter, bid)
    payment = (await renter.post(f"/bookings/{bid}/pickup/payment", json={"method": "cash"})).json()
    await owner.post(f"/payments/{payment['id']}/mark-cash-paid")
    code = (await renter.post(f"/bookings/{bid}/pickup/otp")).json()["code"]
    wrong = "000000" if code != "000000" else "111111"
    codes = [
        (await owner.post(f"/bookings/{bid}/pickup/otp/verify", json={"code": wrong})).json()[
            "error"
        ]["code"]
        for _ in range(6)
    ]
    assert codes[:5] == ["WRONG_CODE"] * 5 and codes[5] == "RATE_LIMITED"
    # A fresh code works again.
    code = (await renter.post(f"/bookings/{bid}/pickup/otp")).json()["code"]
    r = await owner.post(f"/bookings/{bid}/pickup/otp/verify", json={"code": code})
    assert r.json()["status"] == "active"


async def test_paid_bookings_cannot_be_cancelled(api):
    owner, renter, booking = await approved_booking(api)
    await pickup_photos(owner, renter, booking["id"])
    payment = (
        await renter.post(f"/bookings/{booking['id']}/pickup/payment", json={"method": "cash"})
    ).json()
    await owner.post(f"/payments/{payment['id']}/mark-cash-paid")
    r = await renter.post(f"/bookings/{booking['id']}/cancel", json={"note": "Changed my mind"})
    assert r.json()["error"]["code"] == "ALREADY_PAID"


async def test_a_sale_handover_moves_to_reviews(api):
    owner, renter, booking = await approved_booking(api, kind="sale", sale_price_paise=150000)
    await pickup_photos(owner, renter, booking["id"])
    done = await pay_cash_and_hand_over(owner, renter, booking["id"])
    assert done["status"] == "awaiting_reviews"
