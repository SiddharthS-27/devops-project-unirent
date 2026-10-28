from tests.conftest import upload_photo
from tests.test_reviews import reviewable_sale


async def test_a_sale_moves_the_asset_and_its_history_to_the_buyer(api):
    seller, buyer, booking = await reviewable_sale(api)
    listing = (await seller.get(f"/listings/{booking['listing']['id']}")).json()
    assert listing["status"] == "sold" and not listing["can_edit"]
    assert (await seller.get("/assets/mine")).json() == []
    [asset] = (await buyer.get("/assets/mine")).json()
    assert [h["kind"] for h in asset["history"]] == ["listed", "sold"]
    assert asset["serial_number"] == "CN1500D-778812"  # the new owner sees it in full

    seen = (await buyer.get(f"/bookings/{booking['id']}")).json()
    assert seen["status"] == "awaiting_reviews"


async def test_the_buyer_can_relist_what_they_bought(api):
    from tests.conftest import payout_ready

    seller, buyer, booking = await reviewable_sale(api)
    [asset] = (await buyer.get("/assets/mine")).json()
    await payout_ready(buyer)
    key = await upload_photo(buyer)
    r = await buyer.post(
        "/listings",
        json={
            "kind": "rent",
            "title": "Canon camera, now mine",
            "category": "cameras",
            "condition": "good",
            "price_per_day_paise": 25000,
            "pickup_point": "Library",
            "photo_keys": [key],
            "asset_id": asset["id"],
        },
    )
    assert r.status_code == 201, r.text
    history = r.json()["asset"]["history"]
    assert [h["kind"] for h in history] == ["listed", "sold", "listed"]
