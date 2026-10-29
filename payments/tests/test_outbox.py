import pytest

from unirent_payments.outbox import emit


class FakeSession:
    def __init__(self):
        self.added = []

    def add(self, obj):
        self.added.append(obj)


def test_payment_events_go_to_payments_topic():
    session = FakeSession()
    emit(session, "PaymentCaptured", "abc", {"amount_paise": 100})
    assert session.added[0].topic == "payments.events"
    with pytest.raises(ValueError):
        emit(session, "BookingRequested", "abc", {})
