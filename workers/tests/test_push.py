import json
import uuid

import httpx
import pytest

from unirent_workers.backend_api import BackendApi
from unirent_workers.consumers.push import RULES, make_handler, pushes_for
from unirent_workers.push import LogSender, PushDelivery


def _booking_payload(**extra) -> dict:
    return {
        "booking_id": str(uuid.uuid4()),
        "listing_title": "Canon camera",
        "renter_id": "renter",
        "owner_id": "owner",
        "requester_name": "Asha",
        "pickup_point": "Gate",
        **extra,
    }


def _event(type_: str, payload: dict) -> dict:
    return {"event_id": str(uuid.uuid4()), "type": type_, "payload": payload}


def test_requests_notify_the_owner_and_decisions_the_requester():
    [push] = pushes_for(_event("BookingRequested", _booking_payload()))
    assert push.account_id == "owner"
    assert push.link.startswith("unirent://bookings/")
    [push] = pushes_for(_event("BookingDecided", _booking_payload(decision="auto_declined")))
    assert push.account_id == "renter"


def test_cancellation_goes_to_the_other_side_with_the_note():
    [push] = pushes_for(
        _event("BookingCancelled", _booking_payload(cancelled_by="owner", note="Lens broke"))
    )
    assert push.account_id == "renter" and "Lens broke" in push.body


def test_payment_events_reach_both_sides():
    payload = _booking_payload(payer_id="renter", payee_id="owner", amount_paise=5000)
    assert {p.account_id for p in pushes_for(_event("PaymentCaptured", payload))} == {
        "renter",
        "owner",
    }
    [push] = pushes_for(_event("PaymentCaptured", payload))[:1]
    assert "₹50" in push.body


def test_unknown_events_send_nothing():
    assert pushes_for(_event("ReconciliationMismatchFound", {})) == []


@pytest.mark.parametrize("event_type", sorted(RULES))
def test_every_rule_handles_a_full_payload(event_type):
    payload = _booking_payload(
        decision="approved",
        cancelled_by="renter",
        note="n",
        payer_id="a",
        payee_id="b",
        amount_paise=100,
        account_id="a",
        thread_id="t",
        status="suspended",
    )
    assert pushes_for(_event(event_type, payload))


class FakeBackend:
    def __init__(self, tokens):
        self.tokens = tokens
        self.deleted = []

    def transport(self):
        def handle(request: httpx.Request) -> httpx.Response:
            if request.method == "DELETE":
                self.deleted.append(request.url.path.rsplit("/", 1)[-1])
                return httpx.Response(204)
            account = request.url.path.split("/")[3]
            return httpx.Response(200, json={"tokens": self.tokens.get(account, [])})

        return httpx.MockTransport(handle)


class DeadTokenSender(LogSender):
    async def send(self, token, push):
        return "dead_token" if token == "dead" else await super().send(token, push)


async def test_delivery_sends_to_every_device_and_drops_dead_tokens():
    fake = FakeBackend({"owner": ["phone", "dead"]})
    sender = DeadTokenSender()
    handler = make_handler(PushDelivery(BackendApi(transport=fake.transport()), sender))
    await handler(_event("BookingRequested", _booking_payload()))
    assert [t for t, _ in sender.sent] == ["phone"]
    assert fake.deleted == ["dead"]
    json.dumps([p.__dict__ for _, p in sender.sent])  # pushes are plain data
