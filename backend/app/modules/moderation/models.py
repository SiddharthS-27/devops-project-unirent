import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, SmallInteger, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Appeal(Base):
    """A dispute handed to the moderators. Handover photos attach automatically;
    `photo_keys` holds the extra ones either side adds."""

    __tablename__ = "appeals"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.bookings.id", ondelete="CASCADE"), index=True
    )
    filed_by_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    filed_by_role: Mapped[str] = mapped_column(String(10))
    reason: Mapped[str] = mapped_column(String(30))
    notes: Mapped[str] = mapped_column(Text)
    photo_keys: Mapped[list[str]] = mapped_column(JSONB, default=list)
    # Where the booking goes back to after the ruling (a sale's awaiting_reviews or completed).
    previous_status: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(10))  # open, ruled, overruled
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Ruling(Base):
    __tablename__ = "rulings"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    appeal_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.appeals.id", ondelete="CASCADE"), index=True
    )
    ruled_by: Mapped[uuid.UUID] = mapped_column(UUID)
    summary: Mapped[str] = mapped_column(Text)
    charge_paise: Mapped[int | None] = mapped_column(BigInteger)
    refund_paise: Mapped[int | None] = mapped_column(BigInteger)
    refund_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    trust_penalty: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    remove_listing: Mapped[bool] = mapped_column(Boolean, default=False)
    account_action: Mapped[dict[str, Any] | None] = mapped_column(JSONB)
    overrules: Mapped[uuid.UUID | None] = mapped_column(UUID)
    ruled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class TrustPenalty(Base):
    """Points a moderator took off one of a student's trust scores."""

    __tablename__ = "trust_penalties"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    role: Mapped[str] = mapped_column(String(10))  # lender or renter
    points: Mapped[int] = mapped_column(SmallInteger)
    reason: Mapped[str] = mapped_column(Text)
    by: Mapped[uuid.UUID] = mapped_column(UUID)
    ruling_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
