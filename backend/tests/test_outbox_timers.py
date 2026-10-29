import uuid
from datetime import timedelta

import pytest

from app.core.clock import now
from app.core.models import OutboxEvent, Timer
from app.core.outbox import emit, topic_for
from app.core.timers import schedule


class FakeSession:
    def __init__(self):
        self.added = []

    def add(self, obj):
        self.added.append(obj)


def test_events_route_to_their_topics():
    assert topic_for("BookingRequested") == "bookings.events"
    assert topic_for("ListingPublished") == "listings.events"
    assert topic_for("AppealRuled") == "moderation.events"
    with pytest.raises(ValueError):
        topic_for("PaymentCaptured")  # payments has its own outbox


def test_emit_adds_an_unsent_event_to_the_session():
    session = FakeSession()
    booking_id = uuid.uuid4()
    event = emit(session, "BookingRequested", booking_id, {"booking_id": str(booking_id)})
    assert session.added == [event]
    assert isinstance(event, OutboxEvent)
    assert event.aggregate_id == str(booking_id)
    assert event.topic == "bookings.events"
    assert event.sent_at is None


def test_schedule_adds_a_timer():
    session = FakeSession()
    due = now() + timedelta(hours=24)
    timer = schedule(session, "request_expiry", uuid.uuid4(), due)
    assert isinstance(timer, Timer)
    assert timer.due_at == due
    assert timer.payload == {}
