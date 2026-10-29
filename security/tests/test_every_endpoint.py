"""Every endpoint has an authorization test.

Statically, against contracts/openapi.json: every operation must require the
bearer token unless it is on the reviewed list below, with the reason. With a
running api (UNIRENT_API_URL), each guarded operation is also called without a
token and must refuse, and internal routes must refuse without the service token."""

import json
import os
import re
from pathlib import Path

import httpx
import pytest

SPEC = Path(__file__).resolve().parents[2] / "contracts" / "openapi.json"

# Operations that legitimately take no user token, and what protects them instead.
PUBLIC = {
    "POST /api/v1/auth/microsoft": "a verified Microsoft ID token; rate limited per IP",
    "POST /api/v1/auth/microsoft/mock-token": "404 outside dev and test",
    "POST /api/v1/auth/phone/mock-token": "404 outside dev and test",
    "POST /api/v1/auth/refresh": "the refresh token itself",
    "POST /api/v1/auth/logout": "the refresh token itself",
    "POST /api/v1/auth/staff/login": "email and password; locked after 5 failures",
    "POST /api/v1/auth/staff/password": "the current password; same limits as login",
    "POST /api/v1/payments/webhooks/razorpay": "the X-Razorpay-Signature HMAC",
    # The token is optional here (only the rate limit uses it): public reference data.
    "GET /api/v1/categories": "the fixed category list",
    "GET /api/v1/time": "the server clock, for countdowns",
    "GET /healthz": "no data",
    "GET /readyz": "no data",
}
SERVICE_TOKEN_PREFIX = "/internal/"


def operations() -> list[tuple[str, str, dict]]:
    if not SPEC.exists():
        pytest.skip("contracts/openapi.json not present")
    spec = json.loads(SPEC.read_text())
    return [
        (method.upper(), path, op)
        for path, ops in spec["paths"].items()
        for method, op in ops.items()
    ]


def test_every_operation_is_guarded_or_reviewed():
    unguarded = [
        f"{m} {p}"
        for m, p, op in operations()
        if not op.get("security")
        and f"{m} {p}" not in PUBLIC
        and not p.startswith(SERVICE_TOKEN_PREFIX)
    ]
    assert unguarded == [], f"add authentication or a reviewed reason for: {unguarded}"


def test_the_reviewed_list_has_no_stale_entries():
    present = {f"{m} {p}" for m, p, _ in operations()}
    assert set(PUBLIC) <= present


API = os.environ.get("UNIRENT_API_URL")
live = pytest.mark.skipif(not API, reason="set UNIRENT_API_URL to call a running api")


def _concrete(path: str) -> str:
    return re.sub(r"\{[^}]+\}", "00000000-0000-0000-0000-000000000000", path)


@live
def test_every_guarded_operation_refuses_without_a_token():
    # 429 too: the per-IP limit for anonymous callers can answer before authentication.
    refused = {401, 403, 429}
    with httpx.Client(base_url=API, timeout=10) as client:
        for method, path, _ in operations():
            name = f"{method} {path}"
            if name in PUBLIC:
                continue
            r = client.request(method, _concrete(path), json={} if method != "GET" else None)
            assert r.status_code in refused, f"{name} answered {r.status_code} without a token"
