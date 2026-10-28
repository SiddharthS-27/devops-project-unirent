import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from unirent_workers.db import Base


class ProcessedEvent(Base):
    """Events each consumer has handled, so a redelivered event is skipped."""

    __tablename__ = "processed_events"

    consumer: Mapped[str] = mapped_column(String(50), primary_key=True)
    event_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True)
    outcome: Mapped[str] = mapped_column(String(20))
    processed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class DeadLetter(Base):
    """An event that failed every retry; it also went to the topic's .dlq."""

    __tablename__ = "dead_letters"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    consumer: Mapped[str] = mapped_column(String(50))
    topic: Mapped[str] = mapped_column(String(100))
    event_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    type: Mapped[str | None] = mapped_column(String(100))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB)
    error: Mapped[str] = mapped_column(Text)
    failed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
