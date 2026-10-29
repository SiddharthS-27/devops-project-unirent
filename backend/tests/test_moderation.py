from datetime import datetime, timedelta

from app.core import clock
from app.modules.bookings import rental
from tests.conftest import approved_booking, create_listing, lister, moderator, onboard
from tests.test_booking_requests import _period
from tests.test_rental import _run, active_rental, time_travel  # noqa: F401 - fixture


async def test_overdue_rentals_reach_the_escalation_queue(api, time_travel):  # noqa: F811
    owner, renter, booking = await active_rental(api)
    end = datetime.fromisoformat(booking["end_at"])
    time_travel(end - clock.now() + timedelta(minutes=35))
    await _run(rental.mark_overdue, booking["id"])
    mod = await moderator(api)
    ids = [e["booking"]["id"] for e in (await mod.get("/staff/escalations")).json()]
    assert booking["id"] not in ids  # not yet an hour overdue
    time_travel(timedelta(hours=1))
    [entry] = [
        e
        for e in (await mod.get("/staff/escalations")).json()
        if e["booking"]["id"] == booking["id"]
    ]
    assert entry["kind"] == "overdue"
    assert entry["renter_residence"]["hostel_name"] == "Ganga"
    assert entry["renter_phone"]


async def test_suspend_penalise_and_reactivate(api):
    mod = await moderator(api)
    student = await onboard(api)
    found = (await mod.get("/staff/users", params={"q": "Asha"})).json()["items"]
    assert any(u["account_id"] == str(student.id) for u in found)

    path = f"/staff/users/{student.id}"
    r = await mod.post(f"{path}/status", json={"status": "suspended", "reason": "Late twice"})
    assert r.json()["status"] == "suspended"
    assert (await student.get("/me")).json()["account"]["status"] == "suspended"
    r = await mod.post(
        f"{path}/trust-penalty",
        json={"role": "renter", "points": 10, "reason": "Rude to the owner"},
    )
    assert r.json()["penalties"][0]["points"] == 10
    r = await mod.post(
        f"/staff/users/{student.id}/status", json={"status": "active", "reason": "Appeal upheld"}
    )
    assert r.json()["status"] == "active"
    assert (await student.get(path)).status_code == 403


async def test_remove_a_listing(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    mod = await moderator(api)
    out = (
        await mod.post(f"/staff/listings/{listing['id']}/remove", json={"reason": "Prohibited"})
    ).json()
    assert out["status"] == "removed"
    assert (await onboard(api)).id and (
        await (await onboard(api)).get(f"/listings/{listing['id']}")
    ).status_code == 404


async def test_three_cancellations_raise_a_risk_flag(api):
    from app.core.db import get_sessionmaker
    from app.modules.moderation.oversight import risk_flags

    owner, renter, booking = await approved_booking(api)
    await renter.post(f"/bookings/{booking['id']}/cancel", json={"note": "Changed my mind"})
    async with get_sessionmaker()() as session:
        assert (await risk_flags(session, [renter.id]))[renter.id] == []  # one isn't a pattern
    for _ in range(2):
        listing = await create_listing(owner)
        r = await renter.post("/bookings", json={"listing_id": listing["id"], **_period()})
        await owner.post(f"/bookings/{r.json()['id']}/approve")
        await renter.post(f"/bookings/{r.json()['id']}/cancel", json={"note": "Changed my mind"})
    mod = await moderator(api)
    detail = (await mod.get(f"/staff/users/{renter.id}")).json()
    assert [f["kind"] for f in detail["risk_flags"]] == ["cancellations"]
    flagged = (await mod.get("/staff/users", params={"flagged": True})).json()["items"]
    assert str(renter.id) in [u["account_id"] for u in flagged]
