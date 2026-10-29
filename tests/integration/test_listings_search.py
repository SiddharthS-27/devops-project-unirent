"""Listings, photos, payout accounts and search, through the running stack."""

import httpx

from fixtures.client import internal
from fixtures.data import listing, onboarded, owner, tag, upload


def test_listing_needs_a_linked_payout_account():
    student = onboarded()
    r = student.post(
        "/listings",
        json={
            "kind": "rent",
            "title": "No payout yet",
            "category": "books",
            "condition": "good",
            "price_per_day_paise": 1000,
            "pickup_point": "Library",
            "photo_keys": [upload(student)],
        },
    )
    assert r.status_code == 409
    assert r.json()["error"]["code"] == "PAYOUT_ACCOUNT_REQUIRED"


def test_payout_account_links_through_razorpay():
    user = onboarded()
    assert user.ok("GET", "/payouts/account")["status"] == "none"
    from fixtures.data import link_payout

    linked = link_payout(user)
    assert linked["ready"] and linked["razorpay_account_id"].startswith("acc_")
    assert user.post("/payouts/account", json={}).status_code == 422


def test_photos_are_served_from_storage():
    lister = owner()
    created = listing(lister)
    url = created["photos"][0]["url"]
    assert httpx.get(url, timeout=20).status_code == 200


def test_type_ahead_and_search_find_a_new_listing():
    t = tag()
    lister = owner()
    created = listing(lister, title=f"Nikon camera {t}")
    searcher = onboarded()
    suggestions = searcher.ok("GET", "/search/suggest", params={"q": f"cam {t[:5]}"})
    assert created["id"] in [s["listing_id"] for s in suggestions]
    results = searcher.ok("GET", "/search", params={"q": t, "category": "cameras"})
    assert [i["id"] for i in results["items"]] == [created["id"]]
    detail = searcher.ok("GET", f"/listings/{created['id']}")
    assert detail["asset"]["serial_number"].startswith("•")


def test_saved_search_matches_for_the_workers():
    t = tag()
    searcher = onboarded()
    saved = searcher.ok("POST", "/saved-searches", 201, json={"q": t})
    created = listing(owner(), title=f"Guitar {t}")
    r = internal("GET", "/internal/saved-searches/matches", params={"listing_id": created["id"]})
    # Other students' saved searches may match too (say, "guitar"); ours must.
    assert saved["id"] in [m["saved_search_id"] for m in r.json()["matches"]]
