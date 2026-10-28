from datetime import timedelta

from tests.conftest import approved_booking, pay_cash_and_hand_over, pickup_photos
from tests.test_rental import time_travel  # noqa: F401 - fixture

RENTER_RATINGS = {"item_care": 5, "return_punctuality": 4, "communication": 5}
LENDER_RATINGS = {
    "item_matches_description": 4,
    "item_condition": 4,
    "handover_punctuality": 5,
    "communication": 3,
}


async def review(user, bid, ratings, comment="Good trade"):
    return await user.post(
        f"/bookings/{bid}/reviews", json={"ratings": ratings, "comment": comment}
    )


async def reviewable_sale(api):
    owner, renter, booking = await approved_booking(api, kind="sale", sale_price_paise=90000)
    await pickup_photos(owner, renter, booking["id"])
    await pay_cash_and_hand_over(owner, renter, booking["id"])
    return owner, renter, booking


async def test_reviews_are_blind_until_both_are_in(api):
    seller, buyer, booking = await reviewable_sale(api)
    bid = booking["id"]
    form = (await buyer.get(f"/bookings/{bid}/review-form")).json()
    assert form["review_type"] == "lender_sale"
    assert [p["key"] for p in form["parameters"]] == list(LENDER_RATINGS)
    assert [b["id"] for b in (await buyer.get("/me/pending-reviews")).json()] == [bid]

    bad = await buyer.post(
        f"/bookings/{bid}/reviews", json={"ratings": {"communication": 5}, "comment": "ok"}
    )
    assert bad.json()["error"]["code"] == "INVALID_RATINGS"
    state = (
        await buyer.post(
            f"/bookings/{bid}/reviews", json={"ratings": LENDER_RATINGS, "comment": "As described"}
        )
    ).json()
    assert state == {**state, "mine_submitted": True, "theirs_submitted": False, "revealed": False}
    assert (await buyer.get(f"/bookings/{bid}")).json()["next_action"]["key"] == "waiting_review"
    hidden = (await buyer.get(f"/profiles/{seller.id}/reviews", params={"role": "lender"})).json()
    assert hidden["items"] == []

    ratings = {"handover_punctuality": 5, "payment_promptness": 5, "communication": 4}
    await seller.post(
        f"/bookings/{bid}/reviews", json={"ratings": ratings, "comment": "Paid on time"}
    )
    done = (await seller.get(f"/bookings/{bid}")).json()
    assert done["status"] == "completed" and done["reviews"]["revealed"]
    shown = (await buyer.get(f"/profiles/{seller.id}/reviews", params={"role": "lender"})).json()
    assert shown["items"][0]["overall"] == 4.0 and shown["items"][0]["comment"] == "As described"
    assert shown["items"][0]["booking_id"] == bid

    again = await review(seller, bid, ratings, "Again")
    assert again.json()["error"]["code"] in ("ALREADY_REVIEWED", "BOOKING_STATE")


async def test_the_waiting_side_is_released_after_24_hours(api, time_travel):  # noqa: F811
    from app.core.config import get_settings
    from tests.test_timers_internal import _due

    seller, buyer, booking = await reviewable_sale(api)
    bid = booking["id"]
    await buyer.post(
        f"/bookings/{bid}/reviews", json={"ratings": LENDER_RATINGS, "comment": "Fine"}
    )
    time_travel(timedelta(hours=24, minutes=1))
    [release] = [t for t in await _due(api, bid) if t["kind"] == "review_release"]
    service = {"X-Service-Token": get_settings().service_token}
    await api.post(f"/internal/timers/{release['id']}/fire", headers=service)
    out = (await buyer.get(f"/bookings/{bid}")).json()
    assert out["status"] == "completed" and out["reviews"]["revealed"]


async def test_completed_trades_count_toward_the_new_badge(api):
    seller, buyer, booking = await reviewable_sale(api)
    await review(buyer, booking["id"], LENDER_RATINGS)
    await review(
        seller,
        booking["id"],
        {"handover_punctuality": 5, "payment_promptness": 5, "communication": 5},
    )
    profile = (await buyer.get(f"/profiles/{seller.id}")).json()
    assert profile["completed_trades"] == 1 and profile["is_new"]
    assert profile["lender"]["rating"] == 4.0 and profile["lender"]["score"] is None
