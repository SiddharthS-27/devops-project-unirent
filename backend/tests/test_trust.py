from app.modules.trust.service import Inputs, scores


def _inputs(**kw) -> Inputs:
    base = {
        "completed_trades": 10,
        "cancellations": 0,
        "lender_ratings": [5.0] * 10,
        "renter_ratings": [5.0] * 10,
        "punctuality": 1.0,
        "damage_free": 1.0,
        "age_days": 365,
    }
    return Inputs(**{**base, **kw})


def test_a_perfect_record_scores_100():
    assert scores(_inputs()) == (100, 100)


def test_nothing_shows_before_five_trades():
    assert scores(_inputs(completed_trades=4)) == (None, None)


def test_cancellations_cost_twice_their_share():
    lender, renter = scores(_inputs(completed_trades=8, cancellations=2))
    # C = 1 - 2*2/10 = 0.6: lender loses 0.15*0.4*100 = 6, renter 0.10*0.4*100 = 4
    assert (lender, renter) == (94, 96)


def test_late_returns_and_damage_hit_only_renter_trust():
    lender, renter = scores(_inputs(punctuality=0.5, damage_free=0.5))
    assert lender == 100
    assert renter == 100 - 10 - 5


def test_new_accounts_and_low_ratings():
    lender, renter = scores(_inputs(age_days=0, lender_ratings=[1.0], renter_ratings=[3.0]))
    assert lender == round(100 * (0.70 * 0 + 0.15 * 1 + 0.15 * 0))
    assert renter == round(100 * (0.5 * 0.5 + 0.2 + 0.1 + 0.1 + 0))


def test_penalties_and_clamping():
    lender, renter = scores(_inputs(lender_penalty=30, renter_penalty=500))
    assert lender == 70 and renter == 0


async def test_a_cancellation_shows_on_the_cancellers_profile(api):
    from tests.conftest import approved_booking

    owner, renter, booking = await approved_booking(api)
    await owner.post(f"/bookings/{booking['id']}/cancel", json={"note": "Lens broke"})
    await renter.post(
        f"/bookings/{booking['id']}/cancellation-rating",
        json={"stars": 2, "comment": "Late notice"},
    )
    profile = (await renter.get(f"/profiles/{owner.id}")).json()
    assert profile["cancellation_count"] == 1
    assert profile["lender"]["rating"] == 2.0  # the owner cancelled as the lender
    assert (await renter.get(f"/profiles/{renter.id}")).json()["cancellation_count"] == 0
