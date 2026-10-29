from datetime import datetime, timedelta

from app.core import clock
from tests.conftest import moderator, onboard


async def test_metrics_and_audit_log_are_admin_only(api):
    admin = await moderator(api, role="admin")
    mod = await moderator(api)
    assert (await mod.get("/admin/metrics")).status_code == 403
    metrics = (await admin.get("/admin/metrics")).json()
    assert metrics["active_listings"] >= 0 and "bookings_by_state" in metrics

    student = await onboard(api)
    await mod.post(
        f"/staff/users/{student.id}/status", json={"status": "suspended", "reason": "Testing"}
    )
    log = (await admin.get("/admin/audit-log", params={"target": f"account:{student.id}"})).json()
    assert log["items"][0]["action"] == "account.status_changed"


async def test_the_staging_clock_moves_time(api):
    admin = await moderator(api, role="admin")
    try:
        before = datetime.fromisoformat((await api.get("/api/v1/time")).json()["now"])
        r = await admin.post("/admin/clock", json={"offset_minutes": 180})
        assert r.json()["offset_minutes"] == 180
        after = datetime.fromisoformat((await api.get("/api/v1/time")).json()["now"])
        assert after - before >= timedelta(minutes=179)
    finally:
        await admin.post("/admin/clock", json={"offset_minutes": 0})
        clock.set_offset(timedelta(0))
