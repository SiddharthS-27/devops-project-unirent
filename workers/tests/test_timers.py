import httpx

from unirent_workers.backend_api import BackendApi
from unirent_workers.timers import run_once


def _backend(due, fire_status=200):
    fired = []

    def handle(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/internal/timers/due":
            return httpx.Response(200, json={"timers": due})
        timer_id = request.url.path.split("/")[3]
        fired.append(timer_id)
        if fire_status != 200:
            return httpx.Response(fire_status, json={"error": {"code": "X"}})
        return httpx.Response(200, json={"fired": timer_id != "already", "outcome": "ok"})

    return BackendApi(transport=httpx.MockTransport(handle)), fired


async def test_fires_every_due_timer():
    due = [{"id": "t1", "kind": "request_expiry"}, {"id": "already", "kind": "review_release"}]
    backend, fired = _backend(due)
    assert await run_once(backend) == 1
    assert fired == ["t1", "already"]


async def test_a_failing_timer_does_not_stop_the_rest():
    backend, fired = _backend([{"id": "a", "kind": "x"}, {"id": "b", "kind": "x"}], 500)
    assert await run_once(backend) == 0
    assert fired == ["a", "b"]
