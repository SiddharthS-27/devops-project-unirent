import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    Computed,
    DateTime,
    ForeignKey,
    Index,
    SmallInteger,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, TSTZRANGE, UUID, ExcludeConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base

# Approved and every later state hold the slot; side paths release it.
HOLDS_SLOT = (
    "approved",
    "active",
    "overdue",
    "returning",
    "in_appeal",
    "awaiting_reviews",
    "completed",
)
HOLDS_SLOT_SQL = "status IN ({})".format(", ".join(f"'{s}'" for s in HOLDS_SLOT))


class Booking(Base):
    """One request to rent or buy, through to completion. Rentals and sales share
    the state machine; sales skip active, overdue and return."""

    __tablename__ = "bookings"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    listing_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("core.listings.id"), index=True)
    asset_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("core.assets.id"))
    kind: Mapped[str] = mapped_column(String(10))  # rent or sale
    status: Mapped[str] = mapped_column(String(20), index=True)
    renter_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)  # the buyer for a sale
    owner_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)  # the seller for a sale
    start_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    end_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    period: Mapped[Any] = mapped_column(
        TSTZRANGE, Computed("tstzrange(start_at, end_at, '[)')", persisted=True)
    )
    amount_paise: Mapped[int] = mapped_column(BigInteger)  # quoted, then locked at approval
    listing_title: Mapped[str] = mapped_column(String(120))
    pickup_point: Mapped[str] = mapped_column(String(200))
    late_fee_rule_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    decline_reason: Mapped[str | None] = mapped_column(Text)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    pickup_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    return_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    return_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    overdue_since: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    escalated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    escalation_note: Mapped[str | None] = mapped_column(Text)
    damage_paise: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
    damage_description: Mapped[str | None] = mapped_column(Text)
    proceeded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reviews_open_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    appeal_window_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        # Two bookings holding the same listing can never overlap in time.
        ExcludeConstraint(
            ("listing_id", "="),
            ("period", "&&"),
            name="ex_bookings_no_overlap",
            using="gist",
            where=text(f"kind = 'rent' AND {HOLDS_SLOT_SQL}"),
        ),
        Index(
            "uq_bookings_one_sale",
            "listing_id",
            unique=True,
            postgresql_where=text(f"kind = 'sale' AND {HOLDS_SLOT_SQL}"),
        ),
    )

    def role_of(self, account_id: uuid.UUID) -> str | None:
        if account_id == self.renter_id:
            return "renter"
        if account_id == self.owner_id:
            return "owner"
        return None


class BookingEvent(Base):
    """Append-only history of every transition, with who did it."""

    __tablename__ = "booking_events"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.bookings.id", ondelete="CASCADE"), index=True
    )
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    actor_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    actor_role: Mapped[str | None] = mapped_column(String(20))  # renter, owner, staff, system
    action: Mapped[str] = mapped_column(String(50))
    from_status: Mapped[str | None] = mapped_column(String(20))
    to_status: Mapped[str | None] = mapped_column(String(20))
    details: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict, server_default="{}")


class HandoverPhoto(Base):
    __tablename__ = "handover_photos"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.bookings.id", ondelete="CASCADE"), index=True
    )
    phase: Mapped[str] = mapped_column(String(10))  # pickup or return
    side: Mapped[str] = mapped_column(String(10))  # renter or owner
    object_key: Mapped[str] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class HandoverOtp(Base):
    """A 6-digit handover code, stored hashed. Valid 15 minutes, 5 tries."""

    __tablename__ = "handover_otps"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.bookings.id", ondelete="CASCADE"), index=True
    )
    phase: Mapped[str] = mapped_column(String(10))
    code_hash: Mapped[str] = mapped_column(Text)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    replaced: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Cancellation(Base):
    """Who cancelled after approval and why; the other side then rates them."""

    __tablename__ = "cancellations"

    booking_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.bookings.id", ondelete="CASCADE"), primary_key=True
    )
    by_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    by_role: Mapped[str] = mapped_column(String(10))
    note: Mapped[str] = mapped_column(Text)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    rating_stars: Mapped[int | None] = mapped_column(SmallInteger)
    rating_comment: Mapped[str | None] = mapped_column(Text)
    rated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
