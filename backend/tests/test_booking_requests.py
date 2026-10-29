from datetime import timedelta

from app.core.clock import now
from tests.conftest import create_listing, lister, onboard


def _period(days_ahead=1, hours=26):
    start = (now() + timedelta(days=days_ahead)).replace(microsecond=0)
    return {"start_at": start.isoformat(), "end_at": (start + timedelta(hours=hours)).isoformat()}


async def _request(student, listing, **period):
    return await student.post(
        "/bookings",
        json={"listing_id": listing["id"], **(period or _period())},
        headers={"Idempotency-Key": f"req-{listing['id']}-{student.id}"},
    )


async def test_quote_uses_day_and_hour_rates(api):
    owner = await lister(api)
    listing = await create_listing(owner)  # 300/day, 20/hour
    renter = await onboard(api)
    q = (
        await renter.get(
            "/bookings/quote", params={"listing_id": listing["id"], **_period(hours=26)}
        )
    ).json()
    assert q["hours"] == 26 and q["amount_paise"] == 30000 + 2 * 2000


async def test_request_approve_and_auto_decline(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    asha, ravi = await onboard(api), await onboard(api)
    r = await _request(asha, listing)
    assert r.status_code == 201, r.text
    a = r.json()
    assert a["status"] == "requested" and a["next_action"]["key"] == "waiting_owner"
    b = (await _request(ravi, listing)).json()

    incoming = (await owner.get("/bookings", params={"role": "owner", "group": "pending"})).json()
    assert {i["id"] for i in incoming["items"]} >= {a["id"], b["id"]}

    approved = await owner.post(f"/bookings/{a['id']}/approve")
    assert approved.json()["status"] == "approved"
    assert approved.json()["renter"]["view"] == "counterparty"  # residence revealed

    ravis = (await ravi.get(f"/bookings/{b['id']}")).json()
    assert ravis["status"] == "declined"
    assert (await asha.get(f"/listings/{listing['id']}")).json()["unavailable"]
    assert not (await owner.get(f"/listings/{listing['id']}")).json()["can_edit"]


async def test_only_the_right_side_can_act(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    renter, stranger = await onboard(api), await onboard(api)
    booking = (await _request(renter, listing)).json()
    r = await renter.post(f"/bookings/{booking['id']}/approve")
    assert r.json()["error"]["code"] == "NOT_YOUR_STEP"
    r = await stranger.get(f"/bookings/{booking['id']}")
    assert r.status_code == 404
    r = await owner.post(f"/bookings/{booking['id']}/withdraw")
    assert r.status_code == 403
    r = await renter.post(f"/bookings/{booking['id']}/withdraw")
    assert r.json()["status"] == "withdrawn"


async def test_request_rules(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    renter = await onboard(api)
    assert (await _request(owner, listing)).json()["error"]["code"] == "OWN_LISTING"
    past = {"start_at": (now() - timedelta(days=1)).isoformat(), "end_at": now().isoformat()}
    r = await renter.post("/bookings", json={"listing_id": listing["id"], **past})
    assert r.json()["error"]["code"] == "START_IN_PAST"
    await _request(renter, listing)
    r = await renter.post(
        "/bookings",
        json={"listing_id": listing["id"], **_period(3)},
    )
    assert r.json()["error"]["code"] == "REQUEST_EXISTS"


async def test_owner_price_change_locks_at_approval(api):
    owner = await lister(api)
    listing = await create_listing(owner, price_per_hour_paise=None)  # 300/day only
    renter = await onboard(api)
    booking = (await _request(renter, listing, **_period(hours=24))).json()
    assert booking["amount_paise"] == 30000
    await owner.patch(f"/listings/{listing['id']}", json={"price_per_day_paise": 25000})
    approved = (await owner.post(f"/bookings/{booking['id']}/approve")).json()
    assert approved["amount_paise"] == 25000
    r = await owner.patch(f"/listings/{listing['id']}", json={"price_per_day_paise": 99999})
    assert r.json()["error"]["code"] == "LISTING_LOCKED"
