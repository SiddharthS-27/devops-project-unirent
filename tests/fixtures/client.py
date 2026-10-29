"""A small client for the running stack, as one signed-in user."""

import os
import uuid
from typing import Any

import httpx

BASE_URL = os.environ.get("BASE_URL", "http://localhost:8000")
SIM_URL = os.environ.get("SIM_URL", "http://localhost:8090")
SERVICE_TOKEN = os.environ.get("SERVICE_TOKEN", "dev-service-token")
DOMAIN = os.environ.get("MS_ALLOWED_DOMAIN", "college.edu")
ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@unirent.in")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "change-me-admin-password")


def raw() -> httpx.Client:
    return httpx.Client(base_url=BASE_URL, timeout=20)


class User:
    """Calls /api/v1 with this user's token. Mutating calls get an Idempotency-Key
    unless one is passed, like the app does per tap."""

    def __init__(self, tokens: dict, email: str):
        self.tokens = tokens
        self.email = email
        self.id = tokens["account"]["id"]
        self.role = tokens["account"]["role"]
        self.http = raw()

    @property
    def headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.tokens['access_token']}"}

    def request(self, method: str, path: str, *, key: str | None = None, **kw: Any):
        headers = {**self.headers, **kw.pop("headers", {})}
        if method in ("POST", "PUT", "PATCH", "DELETE"):
            headers.setdefault("Idempotency-Key", key or uuid.uuid4().hex)
        return self.http.request(method, "/api/v1" + path, headers=headers, **kw)

    def get(self, path: str, **kw: Any):
        return self.request("GET", path, **kw)

    def post(self, path: str, **kw: Any):
        return self.request("POST", path, **kw)

    def put(self, path: str, **kw: Any):
        return self.request("PUT", path, **kw)

    def patch(self, path: str, **kw: Any):
        return self.request("PATCH", path, **kw)

    def delete(self, path: str, **kw: Any):
        return self.request("DELETE", path, **kw)

    def ok(self, method: str, path: str, status: int = 200, **kw: Any) -> Any:
        response = self.request(method, path, **kw)
        assert response.status_code == status, f"{method} {path}: {response.text}"
        return response.json() if response.content else None


def sign_in(email: str | None = None) -> User:
    email = email or f"t{uuid.uuid4().hex[:10]}@{DOMAIN}"
    with raw() as http:
        token = http.post("/api/v1/auth/microsoft/mock-token", json={"email": email})
        assert token.status_code == 200, token.text
        pair = http.post("/api/v1/auth/microsoft", json=token.json())
        assert pair.status_code == 200, pair.text
    return User(pair.json(), email)


def staff_sign_in(email: str, password: str) -> User:
    with raw() as http:
        r = http.post("/api/v1/auth/staff/login", json={"email": email, "password": password})
        assert r.status_code == 200, r.text
        tokens = r.json()
        if tokens["account"]["must_change_password"]:
            # Satisfy the first-login change, then set the known password back,
            # so later runs can still sign in with it.
            for current, new in ((password, password + "-tmp"), (password + "-tmp", password)):
                r = http.post(
                    "/api/v1/auth/staff/password",
                    json={"email": email, "current_password": current, "new_password": new},
                )
                assert r.status_code == 200, r.text
            tokens = r.json()
    return User(tokens, email)


def internal(method: str, path: str, **kw: Any) -> httpx.Response:
    with raw() as http:
        return http.request(method, path, headers={"X-Service-Token": SERVICE_TOKEN}, **kw)


def sim() -> httpx.Client:
    return httpx.Client(base_url=SIM_URL, timeout=20)


_admin: User | None = None


def admin() -> User:
    """The admin, signed in once per test session: staff login is limited to
    five attempts per 15 minutes per account."""
    global _admin
    if _admin is None:
        _admin = staff_sign_in(ADMIN_EMAIL, ADMIN_PASSWORD)
    return _admin


def new_moderator() -> User:
    """A moderator the admin creates, signed in with their own password."""
    email = f"mod{uuid.uuid4().hex[:8]}@unirent.in"
    admin().ok(
        "POST",
        "/admin/moderators",
        201,
        json={"email": email, "name": "Test Moderator", "temporary_password": "welcome-pass-1"},
    )
    return staff_sign_in(email, "welcome-pass-1")


def fire_due_timers(ref_id: str | None = None) -> list[str]:
    """Do what the workers' timer runner does, right now: fire every due timer
    (oldest first, page by page). Returns the kinds fired for `ref_id`."""
    fired = []
    while True:
        due = internal("GET", "/internal/timers/due", params={"limit": 500}).json()["timers"]
        if not due:
            return fired
        for timer in due:
            internal("POST", f"/internal/timers/{timer['id']}/fire")
            if timer["ref_id"] == ref_id:
                fired.append(timer["kind"])
