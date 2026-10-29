import base64
import json
import uuid

import httpx
import pytest
from fastapi import Depends, FastAPI
from fastapi.responses import JSONResponse

from unirent_security.errors import ApiError
from unirent_security.models import Account
from unirent_security.ownership import require_owner
from unirent_security.roles import AccountContext, CurrentAccount, require_active, require_role
from unirent_security.tokens import issue_access_token


def _token(role="student", status="active", must_change=False, account_id=None):
    account_id = account_id or uuid.uuid4()
    account = Account(id=account_id, email="x@college.edu", role=role, status=status)
    return issue_access_token(account, must_change_password=must_change)


def _app() -> FastAPI:
    app = FastAPI()

    @app.exception_handler(ApiError)
    async def handle(_, exc: ApiError):
        return JSONResponse({"code": exc.code}, status_code=exc.status_code)

    @app.get("/me")
    async def me(account: CurrentAccount):
        return {"role": account.role}

    @app.get("/staff", dependencies=[Depends(require_role("moderator", "admin"))])
    async def staff():
        return {}

    @app.get("/admin", dependencies=[Depends(require_role("admin"))])
    async def admin():
        return {}

    @app.post("/listings", dependencies=[Depends(require_active)])
    async def new_listing():
        return {}

    return app


async def _get(path, token=None, method="GET"):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    transport = httpx.ASGITransport(app=_app())
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
        return await c.request(method, path, headers=headers)


async def test_missing_or_garbage_token_is_401():
    assert (await _get("/me")).status_code == 401
    r = await _get("/me", "not.a.jwt")
    assert r.status_code == 401 and r.json()["code"] == "INVALID_TOKEN"


@pytest.mark.parametrize(
    "role, path, status",
    [
        ("student", "/staff", 403),
        ("student", "/admin", 403),
        ("moderator", "/staff", 200),
        ("moderator", "/admin", 403),
        ("admin", "/staff", 200),
        ("admin", "/admin", 200),
    ],
)
async def test_require_role(role, path, status):
    assert (await _get(path, _token(role))).status_code == status


async def test_tampered_role_claim_is_rejected():
    token = _token("student")
    header, payload, signature = token.split(".")
    claims = json.loads(base64.urlsafe_b64decode(payload + "=="))
    claims["role"] = "admin"
    forged = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    r = await _get("/admin", f"{header}.{forged}.{signature}")
    assert r.status_code == 401


async def test_password_change_token_only_changes_the_password():
    r = await _get("/staff", _token("moderator", must_change=True))
    assert r.status_code == 403 and r.json()["code"] == "PASSWORD_CHANGE_REQUIRED"


async def test_banned_token_is_refused_and_suspended_cannot_start_things():
    assert (await _get("/me", _token(status="banned"))).status_code == 401
    assert (await _get("/me", _token(status="suspended"))).status_code == 200
    r = await _get("/listings", _token(status="suspended"), method="POST")
    assert r.status_code == 403 and r.json()["code"] == "ACCOUNT_SUSPENDED"


def test_require_owner_allows_owners_and_staff_only():
    owner, renter, stranger = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    require_owner(AccountContext(owner, "student", "active"), owner, renter)
    require_owner(AccountContext(renter, "student", "active"), owner, renter)
    require_owner(AccountContext(stranger, "moderator", "active"), owner, renter)
    with pytest.raises(ApiError) as err:
        require_owner(AccountContext(stranger, "student", "active"), owner, renter)
    assert err.value.status_code == 404
    with pytest.raises(ApiError):
        require_owner(AccountContext(stranger, "admin", "active"), owner, allow_staff=False)
