import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from unirent_payments.models import OutboxEvent

EVENTS = {
    "PaymentCaptured",
    "PaymentFailed",
    "CashMarkedPaid",
    "RefundIssued",
    "ReconciliationMismatchFound",
}


def emit(
    session: AsyncSession, type: str, aggregate_id: uuid.UUID | str, payload: dict[str, Any]
) -> None:
    """Queue a payments.events event in the caller's transaction."""
    if type not in EVENTS:
        raise ValueError(f"unknown payment event {type!r}")
    session.add(
        OutboxEvent(
            id=uuid.uuid4(),
            topic="payments.events",
            type=type,
            version=1,
            aggregate_id=str(aggregate_id),
            payload=payload,
            producer="payments",
            occurred_at=datetime.now(UTC),
        )
    )
