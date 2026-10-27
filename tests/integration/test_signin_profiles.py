"""Sign-in, tokens, onboarding and profile visibility across security and backend."""

import pytest

from fixtures.client import admin, raw, sign_in
from fixtures.data import PROFILE, onboarded

pytestmark = pytest.mark.security


def test_first_sign_in_starts_onboarding():
    user = sign_in()
    me = user.ok("GET", "/me")
    assert me["account"]["role"] == "student"
    assert me["profile"] is None
    assert me["onboarding"]["complete"] is False


def test_other_domains_are_refused():
    with raw() as http:
        token = http.post("/api/v1/auth/microsoft/mock-token", json={"email": "x@gmail.com"})
        r = http.post("/api/v1/auth/microsoft", json=token.json())
    assert r.status_code == 403
    assert r.json()["error"]["code"] == "EMAIL_DOMAIN_NOT_ALLOWED"


def test_refresh_rotates_and_reuse_signs_out():
    user = sign_in()
    first = user.tokens["refresh_token"]
    with raw() as http:
        rotated = http.post("/api/v1/auth/refresh", json={"refresh_token": first})
        assert rotated.status_code == 200
        reused = http.post("/api/v1/auth/refresh", json={"refresh_token": first})
        assert reused.json()["error"]["code"] == "REFRESH_TOKEN_REUSED"
        newest = rotated.json()["refresh_token"]
        assert http.post("/api/v1/auth/refresh", json={"refresh_token": newest}).status_code == 401


def test_onboarding_completes_and_unlocks_listing():
    user = onboarded("Asha Rao")
    me = user.ok("GET", "/me")
    assert me["profile"]["full_name"] == "Asha Rao"
    assert me["profile"]["residence"]["room_number"] == PROFILE["room_number"]


def test_public_profile_hides_private_fields():
    asha, ravi = onboarded(), onboarded()
    view = ravi.ok("GET", f"/profiles/{asha.id}")
    assert view["view"] == "public"
    for private in ("email", "roll_number", "residence"):
        assert private not in view


def test_staff_see_the_staff_view():
    student = onboarded()
    view = admin().ok("GET", f"/profiles/{student.id}")
    assert view["view"] == "staff"
    assert view["email"] == student.email


def test_students_cannot_use_admin_routes():
    student = onboarded()
    assert student.get("/admin/moderators").status_code == 403
