from tests.conftest import PROFILE, onboard, sign_in


async def test_onboarding_steps(api):
    student = await sign_in(api)
    me = (await student.get("/me")).json()
    assert me["profile"] is None
    assert me["onboarding"] == {
        "profile_complete": False,
        "phone_verified": False,
        "terms_accepted": False,
        "complete": False,
    }
    r = await student.post("/me/terms", json={"version": "2026-10"})
    assert r.json()["error"]["code"] == "PROFILE_REQUIRED"

    student = await onboard(api)
    me = (await student.get("/me")).json()
    assert me["onboarding"]["complete"]
    assert me["profile"]["view"] == "own"
    assert me["profile"]["email"] == student.email
    assert me["profile"]["residence"]["hostel_name"] == "Ganga"


async def test_residence_must_match_type(api):
    student = await sign_in(api)
    bad = {**PROFILE, "residence_type": "day_scholar"}
    r = await student.put("/me/profile", json=bad)
    assert r.status_code == 422
    good = {**bad, "home_address": "12 MG Road"}
    r = await student.put("/me/profile", json=good)
    assert r.status_code == 200
    assert r.json()["residence"]["hostel_name"] is None


async def test_other_students_see_only_the_public_view(api):
    asha = await onboard(api)
    ravi = await onboard(api)
    view = (await ravi.get(f"/profiles/{asha.id}")).json()
    assert view["view"] == "public"
    assert view["is_new"] is True
    assert view["phone"].startswith("+91")
    for hidden in ("email", "roll_number", "residence"):
        assert hidden not in view


async def test_unknown_profile_is_404(api):
    student = await sign_in(api)
    r = await student.get("/profiles/00000000-0000-0000-0000-000000000000")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "NOT_FOUND"


async def test_requires_sign_in(api):
    r = await api.get("/api/v1/me")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "UNAUTHENTICATED"
