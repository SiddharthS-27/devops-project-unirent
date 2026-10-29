"""The demo story: an overdue rental (with the staging clock), a damage dispute,
a ruling, an admin overrule, blind reviews, and reconciliation at the end."""

from datetime import datetime, timedelta

import pytest

from fixtures.client import admin, fire_due_timers, new_moderator
from fixtures.data import approved_booking, hand_over, pay_upi, pickup_photos, upload

pytestmark = pytest.mark.bookings

LENDER = {
    "item_matches_description": 4,
    "item_condition": 3,
    "handover_punctuality": 5,
    "communication": 4,
}
RENTER = {"item_care": 2, "return_punctuality": 1, "communication": 3}


@pytest.fixture
def clock():
    """Move the staging clock; always put it back."""
    boss = admin()

    def jump_to(when: datetime) -> None:
        now = datetime.fromisoformat(boss.ok("GET", "/admin/clock")["now"])
        minutes = int((when - now).total_seconds() // 60) + 1
        current = boss.ok("GET", "/admin/clock")["offset_minutes"]
        boss.ok("POST", "/admin/clock", json={"offset_minutes": current + max(minutes, 0)})

    yield jump_to
    boss.ok("POST", "/admin/clock", json={"offset_minutes": 0})


def test_overdue_dispute_ruling_overrule_reviews_and_reconciliation(clock):
    lister, renter, booking = approved_booking()
    bid = booking["id"]
    pickup_photos(lister, renter, bid)
    pay_upi(renter, bid)
    active = hand_over(lister, renter, bid)

    # The clock jumps past the end time, the 30-minute grace period and 2 more hours.
    end = datetime.fromisoformat(active["end_at"])
    clock(end + timedelta(hours=2, minutes=31))
    assert "overdue_start" in fire_due_timers(bid)
    overdue = renter.ok("GET", f"/bookings/{bid}")
    assert overdue["status"] == "overdue"
    rent = overdue["amount_paise"]
    assert overdue["charges"]["late_fee_paise"] == round((1000 + rent * 2 * 2 // 100) / 100) * 100
    clock(end + timedelta(hours=3, minutes=40))
    assert lister.ok("GET", f"/bookings/{bid}")["can_escalate"]
    lister.ok("POST", f"/bookings/{bid}/escalate", json={"note": "Not picking up"})

    # Return: photos, the owner's code, a damage charge the renter disputes.
    renter.ok("POST", f"/bookings/{bid}/return/start")
    for user in (renter, lister):
        user.ok(
            "POST",
            f"/bookings/{bid}/return/photos",
            json={"object_keys": [upload(user, "handover")]},
        )
    code = lister.ok("POST", f"/bookings/{bid}/return/otp")["code"]
    back = renter.ok("POST", f"/bookings/{bid}/return/otp/verify", json={"code": code})
    late_fee = back["charges"]["late_fee_paise"]
    lister.ok(
        "POST",
        f"/bookings/{bid}/damage-charge",
        json={"amount_paise": 50000, "description": "Cracked lens"},
    )
    appeal = renter.ok(
        "POST",
        f"/bookings/{bid}/appeals",
        201,
        json={
            "reason": "damage_dispute",
            "notes": "The crack was there at pickup",
            "photo_keys": [upload(renter, "appeal")],
        },
    )

    # A moderator rules half the charge and a trust penalty; the admin overrules it.
    mod = new_moderator()
    detail = mod.ok("GET", f"/staff/appeals/{appeal['id']}")
    assert len(detail["extra_photos"]) == 1 and len(detail["pickup_photos"]) == 2
    mod.ok(
        "POST",
        f"/staff/appeals/{appeal['id']}/ruling",
        json={
            "summary": "Half the repair",
            "charge_paise": 25000,
            "trust_penalty": {"account_id": renter.id, "role": "renter", "points": 5},
        },
    )
    overruled = admin().ok(
        "POST",
        f"/admin/appeals/{appeal['id']}/overrule",
        json={"summary": "The pickup photos show the crack", "charge_paise": 0},
    )
    assert overruled["appeal"]["status"] == "overruled"
    seen = renter.ok("GET", f"/bookings/{bid}")
    assert seen["status"] == "returning"
    assert seen["charges"]["damage_paise"] == 0 and seen["charges"]["late_fee_paise"] == late_fee

    # The renter pays the late fee, the owner proceeds, both review blind.
    pay_upi(renter, bid, path="return/payment")
    lister.ok("POST", f"/bookings/{bid}/proceed")
    renter.ok(
        "POST",
        f"/bookings/{bid}/reviews",
        201,
        json={"ratings": LENDER, "comment": "Honest in the end"},
    )
    lister.ok(
        "POST",
        f"/bookings/{bid}/reviews",
        201,
        json={"ratings": RENTER, "comment": "Returned late"},
    )
    done = lister.ok("GET", f"/bookings/{bid}")
    assert done["status"] == "completed" and done["reviews"]["revealed"]

    # Reconciliation finds nothing wrong with this booking's payments.
    report = admin().ok("POST", "/admin/reconciliation/run", json={})
    ours = {p["id"] for p in done["payments"]}
    assert [m for m in report["mismatches"] if m["payment_id"] in ours] == []
