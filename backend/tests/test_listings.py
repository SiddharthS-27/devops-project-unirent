from tests.conftest import CAMERA, create_listing, lister, onboard, upload_photo


async def test_listing_needs_a_payout_account(api):
    student = await onboard(api)
    key = await upload_photo(student)
    r = await student.post("/listings", json={**CAMERA, "photo_keys": [key]})
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "PAYOUT_ACCOUNT_REQUIRED"


async def test_create_and_view_a_listing(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    assert listing["status"] == "active"
    assert listing["is_mine"] and listing["can_edit"]
    assert listing["asset"]["serial_number"] == "CN1500D-778812"
    assert listing["photos"][0]["url"].startswith("http")
    assert listing["asset"]["history"][0]["kind"] == "listed"

    other = await onboard(api)
    seen = (await other.get(f"/listings/{listing['id']}")).json()
    assert seen["asset"]["serial_number"] == "••••••••••8812"
    assert not seen["is_mine"] and not seen["can_edit"]
    assert seen["owner"]["is_new"] is True


async def test_owner_edits_and_pauses(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    r = await owner.patch(f"/listings/{listing['id']}", json={"price_per_day_paise": 25000})
    assert r.json()["price_per_day_paise"] == 25000

    other = await onboard(api)
    r = await other.patch(f"/listings/{listing['id']}", json={"title": "Mine now"})
    assert r.status_code == 404

    assert (await owner.post(f"/listings/{listing['id']}/pause")).json()["status"] == "paused"
    assert (await other.get(f"/listings/{listing['id']}")).status_code == 404
    assert (await owner.post(f"/listings/{listing['id']}/resume")).json()["status"] == "active"


async def test_photos_must_be_uploaded_by_the_owner(api):
    owner = await lister(api)
    other = await onboard(api)
    stolen = await upload_photo(other)
    r = await owner.post("/listings", json={**CAMERA, "photo_keys": [stolen]})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "INVALID_PHOTO"

    never_uploaded = f"listing/{owner.id}/nothing.jpg"
    r = await owner.post("/listings", json={**CAMERA, "photo_keys": [never_uploaded]})
    assert r.json()["error"]["code"] == "PHOTO_NOT_UPLOADED"


async def test_sale_listing_needs_a_price(api):
    owner = await lister(api)
    key = await upload_photo(owner)
    body = {**CAMERA, "kind": "sale", "photo_keys": [key]}
    assert (await owner.post("/listings", json=body)).status_code == 422
    body["sale_price_paise"] = 1_500_000
    r = await owner.post("/listings", json=body)
    assert r.status_code == 201
    assert r.json()["price_per_day_paise"] is None


async def test_my_listings_and_photo_rules(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    mine = (await owner.get("/listings/mine")).json()
    assert [m["id"] for m in mine] == [listing["id"]]

    photo_id = listing["photos"][0]["id"]
    r = await owner.delete(f"/listings/{listing['id']}/photos/{photo_id}")
    assert r.json()["error"]["code"] == "LAST_PHOTO"
    key = await upload_photo(owner)
    assert (
        await owner.post(f"/listings/{listing['id']}/photos", json={"object_key": key})
    ).status_code == 201
    assert (await owner.delete(f"/listings/{listing['id']}/photos/{photo_id}")).status_code == 204
