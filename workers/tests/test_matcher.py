import httpx

from unirent_workers.backend_api import BackendApi
from unirent_workers.consumers.matcher import make_handler
from unirent_workers.push import LogSender, PushDelivery


def _backend(matches):
    def handle(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/internal/saved-searches/matches":
            return httpx.Response(
                200, json={"listing_id": "l1", "title": "Canon camera", "matches": matches}
            )
        return httpx.Response(200, json={"tokens": [f"token-{request.url.path.split('/')[3]}"]})

    return BackendApi(transport=httpx.MockTransport(handle))


async def test_each_matching_student_gets_one_push():
    matches = [
        {"saved_search_id": "s1", "account_id": "a", "name": "Cameras"},
        {"saved_search_id": "s2", "account_id": "a", "name": "Canon"},
        {"saved_search_id": "s3", "account_id": "b", "name": None},
    ]
    backend = _backend(matches)
    sender = LogSender()
    handler = make_handler(backend, PushDelivery(backend, sender))
    await handler({"type": "ListingPublished", "payload": {"listing_id": "l1"}})
    pushes = [p for _, p in sender.sent]
    assert [p.account_id for p in pushes] == ["a", "b"]
    assert pushes[0].link == "unirent://listing/l1"
    assert "your saved search" in pushes[1].body


async def test_other_listing_events_are_ignored():
    backend = _backend([{"saved_search_id": "s", "account_id": "a", "name": "x"}])
    sender = LogSender()
    await make_handler(backend, PushDelivery(backend, sender))({"type": "Other", "payload": {}})
    assert sender.sent == []
