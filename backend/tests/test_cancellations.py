from tests.conftest import create_listing, lister, onboard
from tests.test_booking_requests import _request


async def _approved(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    renter = await onboard(api)
    booking = (await _request(renter, listing)).json()
    await owner.post(f"/bookings/{booking['id']}/approve")
    return owner, renter, booking


async def test_cancel_with_a_note_then_the_other_side_rates(api):
    owner, renter, booking = await _approved(api)
    assert (await renter.get(f"/bookings/{booking['id']}")).json()["can_cancel"]
    r = await owner.post(f"/bookings/{booking['id']}/cancel", json={"note": "The lens cracked"})
    out = r.json()
    assert out["status"] == "cancelled" and out["cancellation"]["by"] == "owner"

    seen = (await renter.get(f"/bookings/{booking['id']}")).json()
    assert seen["cancellation"]["note"] == "The lens cracked"
    assert seen["next_action"]["key"] == "rate_cancellation"

    r = await owner.post(
        f"/bookings/{booking['id']}/cancellation-rating", json={"stars": 1, "comment": "self"}
    )
    assert r.status_code == 403
    r = await renter.post(
        f"/bookings/{booking['id']}/cancellation-rating",
        json={"stars": 3, "comment": "Fair enough"},
    )
    assert r.json()["next_action"] is None
    r = await renter.post(
        f"/bookings/{booking['id']}/cancellation-rating", json={"stars": 3, "comment": "Again"}
    )
    assert r.json()["error"]["code"] == "ALREADY_RATED"


async def test_cancel_needs_a_note_and_an_approved_booking(api):
    owner, renter, booking = await _approved(api)
    r = await renter.post(f"/bookings/{booking['id']}/cancel", json={"note": "no"})
    assert r.status_code == 422
    await renter.post(f"/bookings/{booking['id']}/cancel", json={"note": "Plans changed"})
    r = await owner.post(f"/bookings/{booking['id']}/cancel", json={"note": "Me too, sorry"})
    assert r.json()["error"]["code"] == "BOOKING_STATE"
