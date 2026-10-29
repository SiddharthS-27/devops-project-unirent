from datetime import datetime

import httpx

from unirent_workers import reconciliation_trigger
from unirent_workers.backend_api import BackendApi
from unirent_workers.reconciliation_trigger import IST, next_run, trigger


def test_next_run_is_the_coming_two_am_ist():
    assert next_run(datetime(2026, 10, 28, 1, 0, tzinfo=IST)) == datetime(
        2026, 10, 28, 2, 0, tzinfo=IST
    )
    assert next_run(datetime(2026, 10, 28, 2, 0, tzinfo=IST)) == datetime(
        2026, 10, 29, 2, 0, tzinfo=IST
    )
    assert next_run(datetime(2026, 10, 28, 23, 0, tzinfo=IST)) == datetime(
        2026, 10, 29, 2, 0, tzinfo=IST
    )


async def test_trigger_retries_then_succeeds(monkeypatch):
    monkeypatch.setattr(reconciliation_trigger, "RETRY_AFTER", reconciliation_trigger.timedelta(0))
    calls = []

    def handle(request: httpx.Request) -> httpx.Response:
        calls.append(request.url.path)
        if len(calls) == 1:
            return httpx.Response(502, json={"error": {"code": "PAYMENT_PROVIDER_ERROR"}})
        return httpx.Response(200, json={"id": "run-1", "totals": {"mismatches": 0}})

    result = await trigger(BackendApi(transport=httpx.MockTransport(handle)))
    assert result["id"] == "run-1"
    assert calls == ["/internal/reconciliation/run"] * 2
