from tests.conftest import create_listing, lister, onboard


async def test_home_shows_categories_and_others_recent_listings(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    viewer = await onboard(api)
    home = (await viewer.get("/home")).json()
    assert len(home["categories"]) == 9
    assert listing["id"] in [c["id"] for c in home["recent"]]
    own_home = (await owner.get("/home")).json()
    assert listing["id"] not in [c["id"] for c in own_home["recent"]]


async def test_assets_keep_the_serial_private(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    asset_id = listing["asset"]["id"]
    mine = (await owner.get("/assets/mine")).json()
    assert mine[0]["serial_number"] == "CN1500D-778812"
    other = await onboard(api)
    assert (await other.get(f"/assets/{asset_id}")).json()["serial_number"].endswith("8812")
    assert "CN1500D" not in (await other.get(f"/assets/{asset_id}")).text


async def test_an_asset_has_one_open_listing(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    r = await owner.post(
        "/listings",
        json={
            "kind": "rent",
            "title": "Same camera again",
            "category": "cameras",
            "condition": "good",
            "price_per_day_paise": 100,
            "pickup_point": "Gate",
            "photo_keys": [listing["photos"][0]["id"]],
            "asset_id": listing["asset"]["id"],
        },
    )
    assert r.status_code in (409, 422)
