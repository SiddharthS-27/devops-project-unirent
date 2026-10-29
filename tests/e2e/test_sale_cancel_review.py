"""A sale end to end, a cancellation and its rating, and blind reviews."""

import pytest

from fixtures.data import approved_booking, hand_over, pay_upi, pickup_photos

pytestmark = pytest.mark.bookings

LENDER = {
    "item_matches_description": 5,
    "item_condition": 4,
    "handover_punctuality": 5,
    "communication": 4,
}
BUYER = {"handover_punctuality": 5, "payment_promptness": 5, "communication": 5}


def test_a_sale_moves_the_item_and_both_review_blind():
    seller, buyer, booking = approved_booking(
        kind="sale", sale_price_paise=180000, price_per_day_paise=None, price_per_hour_paise=None
    )
    bid = booking["id"]
    pickup_photos(seller, buyer, bid)
    pay_upi(buyer, bid)
    handed = hand_over(seller, buyer, bid)
    assert handed["status"] == "awaiting_reviews"

    listing = seller.ok("GET", f"/listings/{booking['listing']['id']}")
    assert listing["status"] == "sold"
    [asset] = buyer.ok("GET", "/assets/mine")
    assert asset["history"][-1]["kind"] == "sold"

    assert [b["id"] for b in buyer.ok("GET", "/me/pending-reviews")] == [bid]
    form = buyer.ok("GET", f"/bookings/{bid}/review-form")
    assert form["review_type"] == "lender_sale"
    buyer.ok(
        "POST", f"/bookings/{bid}/reviews", 201, json={"ratings": LENDER, "comment": "As described"}
    )
    hidden = buyer.ok("GET", f"/profiles/{seller.id}/reviews", params={"role": "lender"})
    assert hidden["items"] == []
    seller.ok(
        "POST", f"/bookings/{bid}/reviews", 201, json={"ratings": BUYER, "comment": "Quick payer"}
    )
    done = seller.ok("GET", f"/bookings/{bid}")
    assert done["status"] == "completed" and done["reviews"]["revealed"]
    shown = buyer.ok("GET", f"/profiles/{seller.id}/reviews", params={"role": "lender"})
    assert shown["items"][0]["comment"] == "As described"
    assert buyer.ok("GET", f"/profiles/{seller.id}")["completed_trades"] == 1


def test_cancellation_note_rating_and_public_count():
    lister, renter, booking = approved_booking()
    renter.ok("POST", f"/bookings/{booking['id']}/cancel", json={"note": "Exam moved, sorry"})
    seen = lister.ok("GET", f"/bookings/{booking['id']}")
    assert seen["next_action"]["key"] == "rate_cancellation"
    lister.ok(
        "POST",
        f"/bookings/{booking['id']}/cancellation-rating",
        json={"stars": 3, "comment": "Told me in time"},
    )
    profile = lister.ok("GET", f"/profiles/{renter.id}")
    assert profile["cancellation_count"] == 1
    reviews = lister.ok("GET", f"/profiles/{renter.id}/reviews", params={"role": "renter"})
    assert reviews["items"][0]["review_type"] == "cancellation"
