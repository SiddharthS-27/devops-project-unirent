import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Review(Base):
    """One side's review of the other for one booking. Hidden until both sides
    have reviewed or the 24-hour release passes, so neither can retaliate."""

    __tablename__ = "reviews"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.bookings.id", ondelete="CASCADE"), index=True
    )
    reviewer_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    reviewee_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    # renter, lender, renter_sale, lender_sale or cancellation; lender types rate the
    # owner or seller, renter types the renter or buyer.
    review_type: Mapped[str] = mapped_column(String(20))
    # Which of the reviewee's two ratings this counts toward: lender or renter.
    reviewee_role: Mapped[str] = mapped_column(String(10))
    ratings: Mapped[dict[str, Any]] = mapped_column(JSONB)
    overall: Mapped[float] = mapped_column(Numeric(3, 2))
    comment: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revealed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    removed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    removed_reason: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (UniqueConstraint("booking_id", "reviewer_id"),)
