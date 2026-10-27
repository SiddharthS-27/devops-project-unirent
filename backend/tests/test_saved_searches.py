import uuid

from app.core.config import get_settings
from tests.conftest import create_listing, lister, onboard

SERVICE = {"X-Service-Token": get_settings().service_token}


async def _matches(api, listing) -> list:
    r = await api.get(
        "/internal/saved-searches/matches", params={"listing_id": listing["id"]}, headers=SERVICE
    )
    return r.json()["matches"]


async def test_saved_search_matches_new_listings(api):
    tag = uuid.uuid4().hex[:6]
    searcher = await onboard(api)
    r = await searcher.post(
        "/saved-searches",
        json={"name": "Cameras", "q": f"cam{tag}", "category": "cameras", "max_price_paise": 50000},
    )
    assert r.status_code == 201
    saved_id = r.json()["id"]

    owner = await lister(api)
    hit = await create_listing(owner, title=f"Canon cam{tag}era")
    miss = await create_listing(owner, title=f"Canon cam{tag}era pro", price_per_day_paise=99999)

    r = await api.get(
        "/internal/saved-searches/matches", params={"listing_id": hit["id"]}, headers=SERVICE
    )
    assert [m["saved_search_id"] for m in r.json()["matches"]] == [saved_id]
    r = await api.get(
        "/internal/saved-searches/matches", params={"listing_id": miss["id"]}, headers=SERVICE
    )
    assert r.json()["matches"] == []

    home = (await searcher.get("/home")).json()
    assert [m["id"] for m in home["saved_search_matches"]] == [hit["id"]]
    listed = (await searcher.get("/saved-searches")).json()
    assert listed[0]["new_match_count"] == 1
    assert (await searcher.get("/saved-searches")).json()[0]["new_match_count"] == 0


async def test_own_listings_never_match(api):
    tag = uuid.uuid4().hex[:6]
    owner = await lister(api)
    await owner.post("/saved-searches", json={"q": tag})
    listing = await create_listing(owner, title=f"Kettle {tag}")
    assert await _matches(api, listing) == []


async def test_saved_searches_are_private(api):
    a, b = await onboard(api), await onboard(api)
    saved = (await a.post("/saved-searches", json={"q": "guitar"})).json()
    assert (await b.delete(f"/saved-searches/{saved['id']}")).status_code == 404
    assert (await b.get("/saved-searches")).json() == []
    assert (await a.delete(f"/saved-searches/{saved['id']}")).status_code == 204
    assert (await a.post("/saved-searches", json={})).status_code == 422
