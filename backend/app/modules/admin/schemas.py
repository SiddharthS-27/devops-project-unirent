import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class MetricsOut(BaseModel):
    active_listings: int
    bookings_by_state: dict[str, int]
    payment_success_rate: float | None = Field(description="Last 30 days, 0-1")
    open_disputes: int
    overdue_count: int
    students: int
    completed_trades: int


class AuditEntryOut(BaseModel):
    id: int
    at: datetime
    actor_id: uuid.UUID | None
    actor_role: str | None
    action: str
    target: str | None
    details: dict[str, Any]


class ClockIn(BaseModel):
    offset_minutes: int = Field(ge=0, le=60 * 24 * 30)


class ClockOut(BaseModel):
    now: datetime
    offset_minutes: int
