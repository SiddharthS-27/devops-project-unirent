from app.core.config import get_settings


async def test_healthz(client):
    r = await client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


async def test_readyz_reports_each_dependency(client):
    r = await client.get("/readyz")
    body = r.json()
    assert set(body["checks"]) == {"database", "redis"}
    assert r.status_code == (200 if body["status"] == "ok" else 503)


async def test_readyz_is_unavailable_without_a_database(client, monkeypatch):
    monkeypatch.setattr(
        get_settings(), "database_url", "postgresql+asyncpg://nobody:x@127.0.0.1:1/none"
    )
    from app.core import db

    await db.dispose_engine()
    r = await client.get("/readyz")
    assert r.status_code == 503
    assert r.json()["checks"]["database"] == "unavailable"
