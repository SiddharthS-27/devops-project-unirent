import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Index, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class OutboxEvent(Base):
    """An event waiting for the workers' relay to publish it to Kafka."""

    __tablename__ = "outbox"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    topic: Mapped[str] = mapped_column(String(100))
    type: Mapped[str] = mapped_column(String(100))
    version: Mapped[int] = mapped_column(Integer, default=1)
    aggregate_id: Mapped[str] = mapped_column(String(64))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB)
    producer: Mapped[str] = mapped_column(String(50), default="backend")
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        Index("ix_outbox_unsent", "occurred_at", postgresql_where=text("sent_at IS NULL")),
    )


class Timer(Base):
    """A time-based rule waiting to fire. The workers' timer runner finds due rows
    and calls POST /internal/timers/{id}/fire; the rule logic stays here."""

    __tablename__ = "timers"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    kind: Mapped[str] = mapped_column(String(50))
    ref_id: Mapped[uuid.UUID] = mapped_column(UUID)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict, server_default="{}")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    fired_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")

    __table_args__ = (
        Index(
            "ix_timers_pending",
            "due_at",
            postgresql_where=text("fired_at IS NULL AND cancelled_at IS NULL"),
        ),
        Index("ix_timers_ref", "ref_id", "kind"),
    )
