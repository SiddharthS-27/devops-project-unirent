import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Index, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from unirent_payments.db import Base


class OutboxEvent(Base):
    """payments.events waiting for the workers' relay. Same shape as core.outbox."""

    __tablename__ = "outbox"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    topic: Mapped[str] = mapped_column(String(100))
    type: Mapped[str] = mapped_column(String(100))
    version: Mapped[int] = mapped_column(Integer, default=1)
    aggregate_id: Mapped[str] = mapped_column(String(64))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB)
    producer: Mapped[str] = mapped_column(String(50), default="payments")
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        Index("ix_outbox_unsent", "occurred_at", postgresql_where=text("sent_at IS NULL")),
    )


class LinkedAccount(Base):
    """An owner's Razorpay Route linked account. Bank details go straight to
    Razorpay; only the account ID and its status are kept."""

    __tablename__ = "linked_accounts"

    account_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True)
    razorpay_account_id: Mapped[str] = mapped_column(String(50), unique=True)
    route_product_id: Mapped[str | None] = mapped_column(String(50))
    status: Mapped[str] = mapped_column(String(30))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
