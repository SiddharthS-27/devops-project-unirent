from tests.conftest import moderator
from tests.test_rental import active_rental
from tests.test_returns import _back, _return_photos


async def returned_rental(api):
    owner, renter, booking = await active_rental(api)
    bid = booking["id"]
    await renter.post(f"/bookings/{bid}/return/start")
    await _return_photos(renter, bid)
    await _return_photos(owner, bid)
    await _back(owner, renter, bid)
    return owner, renter, bid


async def test_dispute_ruled_with_a_charge_then_paid_and_proceeded(api):
    owner, renter, bid = await returned_rental(api)
    assert (await renter.get(f"/bookings/{bid}")).json()["can_appeal"]
    r = await renter.post(
        f"/bookings/{bid}/appeals",
        json={"reason": "damage_dispute", "notes": "The scratch was there at pickup"},
    )
    assert r.status_code == 201, r.text
    appeal = r.json()
    seen = (await owner.get(f"/bookings/{bid}")).json()
    assert seen["status"] == "in_appeal" and seen["next_action"]["key"] == "waiting_ruling"

    mod = await moderator(api)
    queue = (await mod.get("/staff/appeals")).json()
    assert appeal["id"] in [a["id"] for a in queue]
    detail = (await mod.get(f"/staff/appeals/{appeal['id']}")).json()
    assert len(detail["pickup_photos"]) == 2 and len(detail["return_photos"]) == 2
    assert (await renter.get(f"/staff/appeals/{appeal['id']}")).status_code == 403

    ruling = {
        "summary": "Half the repair cost",
        "charge_paise": 5000,
        "trust_penalty": {"account_id": str(renter.id), "role": "renter", "points": 5},
    }
    ruled = (await mod.post(f"/staff/appeals/{appeal['id']}/ruling", json=ruling)).json()
    assert ruled["appeal"]["status"] == "ruled"
    assert ruled["booking"]["status"] == "returning"
    assert ruled["booking"]["charges"]["damage_paise"] == 5000

    payment = (await renter.post(f"/bookings/{bid}/return/payment", json={"method": "cash"})).json()
    await owner.post(f"/payments/{payment['id']}/mark-cash-paid")
    assert (await owner.post(f"/bookings/{bid}/proceed")).json()["status"] == "awaiting_reviews"


async def test_only_the_admin_overrules_and_effects_are_reversed(api):
    owner, renter, bid = await returned_rental(api)
    appeal = (
        await owner.post(
            f"/bookings/{bid}/appeals", json={"reason": "damage_dispute", "notes": "Lens cracked"}
        )
    ).json()
    mod = await moderator(api)
    ruling = {
        "summary": "Renter suspended for repeated damage",
        "account_action": {"account_id": str(renter.id), "status": "suspended"},
    }
    await mod.post(f"/staff/appeals/{appeal['id']}/ruling", json=ruling)
    assert (await renter.get("/me")).json()["account"]["status"] == "suspended"

    r = await mod.post(f"/admin/appeals/{appeal['id']}/overrule", json={"summary": "No grounds"})
    assert r.status_code == 403

    admin = await moderator(api, role="admin")
    path = f"/admin/appeals/{appeal['id']}/overrule"
    out = (await admin.post(path, json={"summary": "No grounds"})).json()
    assert out["appeal"]["status"] == "overruled"
    assert [r["overrules"] is not None for r in out["rulings"]] == [False, True]
    assert (await renter.get("/me")).json()["account"]["status"] == "active"


async def test_strangers_cannot_appeal(api):
    from tests.conftest import onboard

    owner, renter, bid = await returned_rental(api)
    stranger = await onboard(api)
    r = await stranger.post(
        f"/bookings/{bid}/appeals", json={"reason": "other", "notes": "Not mine"}
    )
    assert r.status_code == 404
