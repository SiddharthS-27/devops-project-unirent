"""Privilege escalation on admin, staff, settlement and internal routes, and
tokens that were tampered with or forged."""

import base64
import json

import httpx
import pytest

from fixtures.client import BASE_URL, User, admin, raw
from fixtures.data import onboarded

pytestmark = pytest.mark.security

ADMIN_ROUTES = [
    ("GET", "/admin/moderators", None),
    (
        "POST",
        "/admin/moderators",
        {"email": "x@unirent.in", "name": "X", "temporary_password": "aaaaaaaaaaaa"},
    ),
    ("GET", "/admin/metrics", None),
    ("GET", "/admin/audit-log", None),
    ("GET", "/admin/late-fee-rule", None),
    (
        "POST",
        "/admin/late-fee-rule",
        {"grace_minutes": 0, "base_fee_paise": 0, "hourly_percent_bp": 0},
    ),
    ("GET", "/admin/reconciliation/runs", None),
    ("POST", "/admin/reconciliation/run", {}),
    ("POST", "/admin/clock", {"offset_minutes": 600}),
    (
        "POST",
        "/admin/appeals/00000000-0000-0000-0000-000000000000/overrule",
        {"summary": "Mine now"},
    ),
]
STAFF_ROUTES = [
    ("GET", "/staff/appeals", None),
    ("GET", "/staff/escalations", None),
    ("GET", "/staff/users", None),
    ("GET", "/staff/support/threads", None),
    ("GET", "/staff/listings", None),
]


@pytest.fixture(scope="module")
def student() -> User:
    return onboarded("Mallory")


@pytest.fixture(scope="module")
def mod() -> User:
    """A moderator created by the admin, as the app does it."""
    import uuid

    from fixtures.client import staff_sign_in

    email = f"mod{uuid.uuid4().hex[:8]}@unirent.in"
    admin().ok(
        "POST",
        "/admin/moderators",
        201,
        json={"email": email, "name": "Test Mod", "temporary_password": "welcome-pass-1"},
    )
    return staff_sign_in(email, "welcome-pass-1")


def _call(user: User, method: str, path: str, body):
    return user.request(method, path, **({"json": body} if body is not None else {}))


@pytest.mark.parametrize("method, path, body", ADMIN_ROUTES)
def test_students_and_moderators_cannot_use_admin_routes(student, mod, method, path, body):
    for user in (student, mod):
        r = _call(user, method, path, body)
        assert r.status_code == 403, (user.role, path, r.text)


@pytest.mark.parametrize("method, path, body", STAFF_ROUTES)
def test_students_cannot_use_staff_routes(student, method, path, body):
    assert _call(student, method, path, body).status_code == 403


def _b64(data: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(data).encode()).rstrip(b"=").decode()


def _claims(token: str) -> dict:
    payload = token.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))


def test_tampered_and_forged_tokens_are_rejected(student):
    header, _, signature = student.tokens["access_token"].split(".")
    claims = {**_claims(student.tokens["access_token"]), "role": "admin"}
    tampered = f"{header}.{_b64(claims)}.{signature}"
    unsigned = f"{_b64({'alg': 'none', 'typ': 'JWT'})}.{_b64(claims)}."
    forged = f"{_b64({'alg': 'HS256', 'typ': 'JWT'})}.{_b64(claims)}.{signature}"
    for token in (tampered, unsigned, forged, "garbage"):
        with raw() as http:
            r = http.get("/api/v1/admin/metrics", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 401, token[:20]


def test_internal_routes_need_the_service_token(student):
    for method, path in [
        ("GET", "/internal/timers/due"),
        ("POST", "/internal/reconciliation/run"),
        ("GET", f"/internal/accounts/{student.id}/push-tokens"),
    ]:
        r = httpx.request(method, BASE_URL + path, headers=student.headers, timeout=10)
        assert r.status_code == 401, path


def test_a_student_cannot_promote_themselves(student):
    r = student.put(
        "/me/profile",
        json={
            "full_name": "Mallory",
            "roll_number": "X1",
            "department": "CS",
            "year": 2,
            "residence_type": "hostel",
            "hostel_name": "Ganga",
            "room_number": "1",
            "role": "admin",
        },
    )
    assert r.status_code == 200
    assert student.ok("GET", "/me")["account"]["role"] == "student"
