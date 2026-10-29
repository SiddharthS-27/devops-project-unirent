from datetime import datetime, timedelta

from app.core import clock
from app.modules.bookings import rental
from tests.conftest import upload_photo
from tests.test_rental import _run, active_rental, time_travel  # noqa: F401 - fixture


async def _return_photos(user, bid):
    key = await upload_photo(user, "handover")
    return await user.post(f"/bookings/{bid}/return/photos", json={"object_keys": [key]})


async def _back(owner, renter, bid):
    code = (await owner.post(f"/bookings/{bid}/return/otp")).json()["code"]
    return await renter.post(f"/bookings/{bid}/return/otp/verify", json={"code": code})


async def test_late_return_with_damage_then_proceed(api, time_travel):  # noqa: F811
    owner, renter, booking = await active_rental(api)
    bid = booking["id"]
    end = datetime.fromisoformat(booking["end_at"])
    time_travel(end - clock.now() + timedelta(minutes=95))  # 1h05m past the grace period
    await _run(rental.mark_overdue, bid)

    out = (await renter.post(f"/bookings/{bid}/return/start")).json()
    assert out["status"] == "returning" and out["next_action"]["key"] == "upload_return_photos"
    r = await _return_photos(owner, bid)
    assert r.json()["error"]["code"] == "STEP_LOCKED"  # the renter's photos come first
    await _return_photos(renter, bid)
    await _return_photos(owner, bid)
    back = (await _back(owner, renter, bid)).json()
    fee = back["charges"]["late_fee_paise"]
    assert fee == round((1000 + back["amount_paise"] * 2 // 100) / 100) * 100

    time_travel(timedelta(hours=3))  # the fee stopped when the item came back
    assert (await renter.get(f"/bookings/{bid}")).json()["charges"]["late_fee_paise"] == fee

    r = await owner.post(
        f"/bookings/{bid}/damage-charge",
        json={"amount_paise": 20000, "description": "Scratched lens cap"},
    )
    assert r.json()["charges"]["total_paise"] == fee + 20000
    assert (await owner.post(f"/bookings/{bid}/proceed")).json()["error"][
        "code"
    ] == "CHARGES_UNPAID"

    payment = (await renter.post(f"/bookings/{bid}/return/payment", json={"method": "cash"})).json()
    assert [i["label"] for i in payment["items"]] == ["Late fee", "Damage charge"]
    await owner.post(f"/payments/{payment['id']}/mark-cash-paid")
    done = (await owner.post(f"/bookings/{bid}/proceed")).json()
    assert done["status"] == "awaiting_reviews"

    asset = (
        await owner.get(f"/assets/{done['listing']['id']}")
    ).status_code  # listing id isn't an asset
    assert asset == 404


async def test_on_time_return_needs_no_payment(api):
    owner, renter, booking = await active_rental(api)
    bid = booking["id"]
    await renter.post(f"/bookings/{bid}/return/start")
    await _return_photos(renter, bid)
    await _return_photos(owner, bid)
    back = (await _back(owner, renter, bid)).json()
    assert back["charges"]["total_paise"] == 0 and back["charges"]["paid"]
    assert back["next_action"]["key"] == "waiting_proceed"
    r = await renter.post(f"/bookings/{bid}/return/payment", json={"method": "cash"})
    assert r.json()["error"]["code"] == "NOTHING_TO_PAY"
    assert (await owner.post(f"/bookings/{bid}/proceed")).json()["status"] == "awaiting_reviews"
