import uuid

from tests.conftest import create_listing, lister, onboard


def _unique() -> str:
    return uuid.uuid4().hex[:6]


async def test_type_ahead_finds_partly_typed_titles(api):
    tag = _unique()
    owner = await lister(api)
    await create_listing(owner, title=f"Canon camera {tag}")
    searcher = await onboard(api)
    r = await searcher.get("/search/suggest", params={"q": f"cam {tag}"})
    assert any(tag in s["title"] for s in r.json())
    r = await searcher.get("/search/suggest", params={"q": tag[:4]})
    assert any(tag in s["title"] for s in r.json())


async def test_full_text_matches_description_and_category(api):
    tag = _unique()
    owner = await lister(api)
    listing = await create_listing(owner, title=f"Tripod {tag}", description=f"Sturdy {tag}x stand")
    searcher = await onboard(api)
    r = await searcher.get("/search", params={"q": f"{tag}x"})
    assert [i["id"] for i in r.json()["items"]] == [listing["id"]]


async def test_paused_listings_are_not_found(api):
    tag = _unique()
    owner = await lister(api)
    listing = await create_listing(owner, title=f"Ukulele {tag}")
    await owner.post(f"/listings/{listing['id']}/pause")
    searcher = await onboard(api)
    assert (await searcher.get("/search", params={"q": tag})).json()["items"] == []
    assert (await searcher.get("/search/suggest", params={"q": tag})).json() == []


async def test_results_page_with_a_cursor(api):
    tag = _unique()
    owner = await lister(api)
    for n in range(3):
        await create_listing(owner, title=f"Book {tag} volume {n}")
    searcher = await onboard(api)
    first = (await searcher.get("/search", params={"q": tag, "limit": 2, "sort": "newest"})).json()
    assert len(first["items"]) == 2 and first["next_cursor"]
    second = (
        await searcher.get(
            "/search",
            params={"q": tag, "limit": 2, "sort": "newest", "cursor": first["next_cursor"]},
        )
    ).json()
    assert len(second["items"]) == 1 and second["next_cursor"] is None


async def test_odd_input_is_safe(api):
    searcher = await onboard(api)
    for q in ("%", "_", "' OR 1=1 --", "cam:*&|!"):
        assert (await searcher.get("/search", params={"q": q})).status_code == 200
        assert (await searcher.get("/search/suggest", params={"q": q})).status_code == 200
    assert (await searcher.get("/search", params={"cursor": "garbage!"})).status_code == 422
