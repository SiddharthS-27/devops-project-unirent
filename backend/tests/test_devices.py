import uuid

from app.core.config import get_settings
from tests.conftest import sign_in


async def test_register_list_and_remove_push_tokens(api):
    student = await sign_in(api)
    token = f"fcm-{uuid.uuid4().hex}"
    r = await student.post("/devices/push-tokens", json={"token": token, "platform": "android"})
    assert r.status_code == 204

    service = {"X-Service-Token": get_settings().service_token}
    r = await api.get(f"/internal/accounts/{student.id}/push-tokens", headers=service)
    assert r.json() == {"tokens": [token]}

    # The same device signing in as someone else moves the token.
    other = await sign_in(api)
    await other.post("/devices/push-tokens", json={"token": token, "platform": "android"})
    r = await api.get(f"/internal/accounts/{student.id}/push-tokens", headers=service)
    assert r.json() == {"tokens": []}

    assert (await api.delete(f"/internal/push-tokens/{token}", headers=service)).status_code == 204
    r = await api.get(f"/internal/accounts/{other.id}/push-tokens", headers=service)
    assert r.json() == {"tokens": []}


async def test_internal_routes_need_the_service_token(api):
    r = await api.get(f"/internal/accounts/{uuid.uuid4()}/push-tokens")
    assert r.status_code == 401
    r = await api.get(
        f"/internal/accounts/{uuid.uuid4()}/push-tokens", headers={"X-Service-Token": "nope"}
    )
    assert r.status_code == 401


async def test_reconciliation_route_is_mounted_behind_the_service_token(api):
    r = await api.post("/internal/reconciliation/run", json={})
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "SERVICE_TOKEN_REQUIRED"
