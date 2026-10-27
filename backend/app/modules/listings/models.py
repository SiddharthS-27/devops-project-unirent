import uuid
from datetime import date, datetime
from typing import Any

from sqlalchemy import (
    BigInteger,
    Computed,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, TSVECTOR, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Asset(Base):
    """The physical item. It outlives listings and owners: when it is sold, the
    record and its whole history move to the buyer."""

    __tablename__ = "assets"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    category: Mapped[str] = mapped_column(String(20))
    condition: Mapped[str] = mapped_column(String(20))
    manufacture_date: Mapped[date | None] = mapped_column(Date)
    serial_number: Mapped[str | None] = mapped_column(String(100))
    rental_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class AssetEvent(Base):
    """One line of an asset's history: listed, rented, returned, sold, damage."""

    __tablename__ = "asset_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    asset_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.assets.id", ondelete="CASCADE"), index=True
    )
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    kind: Mapped[str] = mapped_column(String(20))
    summary: Mapped[str] = mapped_column(Text)
    amount_paise: Mapped[int | None] = mapped_column(BigInteger)
    booking_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    photo_keys: Mapped[list[str]] = mapped_column(JSONB, default=list, server_default="[]")


SEARCH_VECTOR = (
    "setweight(to_tsvector('english', coalesce(title, '')), 'A') || "
    "setweight(to_tsvector('english', coalesce(description, '')), 'B') || "
    "setweight(to_tsvector('english', category), 'C')"
)


class Listing(Base):
    """One offer of an asset, for rent or for sale, never both."""

    __tablename__ = "listings"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    asset_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("core.assets.id"), index=True)
    owner_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    kind: Mapped[str] = mapped_column(String(10))
    status: Mapped[str] = mapped_column(String(10))
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(20))
    price_per_hour_paise: Mapped[int | None] = mapped_column(BigInteger)
    price_per_day_paise: Mapped[int | None] = mapped_column(BigInteger)
    sale_price_paise: Mapped[int | None] = mapped_column(BigInteger)
    pickup_point: Mapped[str] = mapped_column(String(200))
    removed_reason: Mapped[str | None] = mapped_column(Text)
    search_vector: Mapped[Any] = mapped_column(TSVECTOR, Computed(SEARCH_VECTOR, persisted=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        Index("ix_listings_search_vector", "search_vector", postgresql_using="gin"),
        Index(
            "ix_listings_title_trgm",
            "title",
            postgresql_using="gin",
            postgresql_ops={"title": "gin_trgm_ops"},
        ),
        Index("ix_listings_status_created", "status", "created_at"),
        Index(
            "uq_listings_one_open_per_asset",
            "asset_id",
            unique=True,
            postgresql_where=text("status IN ('active', 'paused')"),
        ),
    )

    @property
    def price_paise(self) -> int:
        """The price that filters and sorts use: sale price, else daily, else hourly."""
        return self.sale_price_paise or self.price_per_day_paise or self.price_per_hour_paise or 0


class ListingPhoto(Base):
    __tablename__ = "listing_photos"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.listings.id", ondelete="CASCADE"), index=True
    )
    object_key: Mapped[str] = mapped_column(String(300))
    position: Mapped[int] = mapped_column(SmallInteger)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
