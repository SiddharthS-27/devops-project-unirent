"""assets and listings

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

C = "core"
SEARCH_VECTOR = (
    "setweight(to_tsvector('english', coalesce(title, '')), 'A') || "
    "setweight(to_tsvector('english', coalesce(description, '')), 'B') || "
    "setweight(to_tsvector('english', category), 'C')"
)


def upgrade() -> None:
    op.create_table(
        "assets",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("owner_id", postgresql.UUID(), nullable=False),
        sa.Column("category", sa.String(20), nullable=False),
        sa.Column("condition", sa.String(20), nullable=False),
        sa.Column("manufacture_date", sa.Date()),
        sa.Column("serial_number", sa.String(100)),
        sa.Column("rental_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        schema=C,
    )
    op.create_index("ix_assets_owner_id", "assets", ["owner_id"], schema=C)
    op.create_table(
        "asset_events",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "asset_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.assets.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("amount_paise", sa.BigInteger()),
        sa.Column("booking_id", postgresql.UUID()),
        sa.Column("photo_keys", postgresql.JSONB(), server_default="[]", nullable=False),
        schema=C,
    )
    op.create_index("ix_asset_events_asset_id", "asset_events", ["asset_id"], schema=C)
    op.create_table(
        "listings",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("asset_id", postgresql.UUID(), sa.ForeignKey(f"{C}.assets.id"), nullable=False),
        sa.Column("owner_id", postgresql.UUID(), nullable=False),
        sa.Column("kind", sa.String(10), nullable=False),
        sa.Column("status", sa.String(10), nullable=False),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("category", sa.String(20), nullable=False),
        sa.Column("price_per_hour_paise", sa.BigInteger()),
        sa.Column("price_per_day_paise", sa.BigInteger()),
        sa.Column("sale_price_paise", sa.BigInteger()),
        sa.Column("pickup_point", sa.String(200), nullable=False),
        sa.Column("removed_reason", sa.Text()),
        sa.Column(
            "search_vector", postgresql.TSVECTOR(), sa.Computed(SEARCH_VECTOR, persisted=True)
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("kind IN ('rent', 'sale')", name="kind"),
        sa.CheckConstraint("status IN ('active', 'paused', 'sold', 'removed')", name="status"),
        sa.CheckConstraint(
            "(kind = 'rent' AND sale_price_paise IS NULL AND "
            "coalesce(price_per_hour_paise, price_per_day_paise) IS NOT NULL) OR "
            "(kind = 'sale' AND sale_price_paise IS NOT NULL)",
            name="price_matches_kind",
        ),
        schema=C,
    )
    op.create_index("ix_listings_asset_id", "listings", ["asset_id"], schema=C)
    op.create_index("ix_listings_owner_id", "listings", ["owner_id"], schema=C)
    op.create_index("ix_listings_status_created", "listings", ["status", "created_at"], schema=C)
    op.create_index(
        "ix_listings_search_vector",
        "listings",
        ["search_vector"],
        schema=C,
        postgresql_using="gin",
    )
    op.execute(
        "CREATE INDEX ix_listings_title_trgm ON core.listings USING gin (title gin_trgm_ops)"
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_listings_one_open_per_asset ON core.listings (asset_id) "
        "WHERE status IN ('active', 'paused')"
    )
    op.create_table(
        "listing_photos",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "listing_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.listings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("object_key", sa.String(300), nullable=False),
        sa.Column("position", sa.SmallInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        schema=C,
    )
    op.create_index("ix_listing_photos_listing_id", "listing_photos", ["listing_id"], schema=C)


def downgrade() -> None:
    op.drop_table("listing_photos", schema=C)
    op.drop_table("listings", schema=C)
    op.drop_table("asset_events", schema=C)
    op.drop_table("assets", schema=C)
