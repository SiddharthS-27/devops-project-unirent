"""bookings, booking events, handover photos and codes, cancellations

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008"
down_revision: str | None = "0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

C = "core"
HOLDS_SLOT = (
    "status IN ('approved', 'active', 'overdue', 'returning', 'in_appeal', "
    "'awaiting_reviews', 'completed')"
)
STATUSES = (
    "'requested', 'approved', 'declined', 'withdrawn', 'expired', 'cancelled', 'active', "
    "'overdue', 'returning', 'in_appeal', 'awaiting_reviews', 'completed'"
)


def _ts(name: str, nullable: bool = True) -> sa.Column:
    return sa.Column(name, sa.DateTime(timezone=True), nullable=nullable)


def upgrade() -> None:
    op.create_table(
        "bookings",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "listing_id", postgresql.UUID(), sa.ForeignKey(f"{C}.listings.id"), nullable=False
        ),
        sa.Column("asset_id", postgresql.UUID(), sa.ForeignKey(f"{C}.assets.id"), nullable=False),
        sa.Column("kind", sa.String(10), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("renter_id", postgresql.UUID(), nullable=False),
        sa.Column("owner_id", postgresql.UUID(), nullable=False),
        _ts("start_at"),
        _ts("end_at"),
        sa.Column(
            "period",
            postgresql.TSTZRANGE(),
            sa.Computed("tstzrange(start_at, end_at, '[)')", persisted=True),
        ),
        sa.Column("amount_paise", sa.BigInteger(), nullable=False),
        sa.Column("listing_title", sa.String(120), nullable=False),
        sa.Column("pickup_point", sa.String(200), nullable=False),
        sa.Column("late_fee_rule_id", postgresql.UUID()),
        sa.Column("decline_reason", sa.Text()),
        _ts("decided_at"),
        _ts("pickup_completed_at"),
        _ts("return_started_at"),
        _ts("return_completed_at"),
        _ts("overdue_since"),
        _ts("escalated_at"),
        sa.Column("escalation_note", sa.Text()),
        sa.Column("damage_paise", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("damage_description", sa.Text()),
        _ts("proceeded_at"),
        _ts("reviews_open_at"),
        _ts("appeal_window_until"),
        _ts("completed_at"),
        _ts("created_at", False),
        _ts("updated_at", False),
        sa.CheckConstraint("kind IN ('rent', 'sale')", name="kind"),
        sa.CheckConstraint(f"status IN ({STATUSES})", name="status"),
        sa.CheckConstraint("renter_id <> owner_id", name="not_own_listing"),
        sa.CheckConstraint(
            "(kind = 'rent' AND start_at IS NOT NULL AND end_at > start_at) OR kind = 'sale'",
            name="rent_has_period",
        ),
        schema=C,
    )
    for column in ("listing_id", "status", "renter_id", "owner_id"):
        op.create_index(f"ix_bookings_{column}", "bookings", [column], schema=C)
    # The concurrent-reservation guarantee: approved rentals of one listing never overlap.
    op.execute(
        "ALTER TABLE core.bookings ADD CONSTRAINT ex_bookings_no_overlap "
        "EXCLUDE USING gist (listing_id WITH =, period WITH &&) "
        f"WHERE (kind = 'rent' AND {HOLDS_SLOT})"
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_bookings_one_sale ON core.bookings (listing_id) "
        f"WHERE kind = 'sale' AND {HOLDS_SLOT}"
    )
    op.create_table(
        "booking_events",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.bookings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        _ts("at", False),
        sa.Column("actor_id", postgresql.UUID()),
        sa.Column("actor_role", sa.String(20)),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("from_status", sa.String(20)),
        sa.Column("to_status", sa.String(20)),
        sa.Column("details", postgresql.JSONB(), nullable=False, server_default="{}"),
        schema=C,
    )
    op.create_index("ix_booking_events_booking_id", "booking_events", ["booking_id"], schema=C)
    op.create_table(
        "handover_photos",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.bookings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("phase", sa.String(10), nullable=False),
        sa.Column("side", sa.String(10), nullable=False),
        sa.Column("object_key", sa.String(300), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        schema=C,
    )
    op.create_index("ix_handover_photos_booking_id", "handover_photos", ["booking_id"], schema=C)
    op.create_table(
        "handover_otps",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.bookings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("phase", sa.String(10), nullable=False),
        sa.Column("code_hash", sa.Text(), nullable=False),
        _ts("expires_at", False),
        _ts("used_at"),
        sa.Column("replaced", sa.Boolean(), nullable=False, server_default="false"),
        _ts("created_at", False),
        schema=C,
    )
    op.create_index("ix_handover_otps_booking_id", "handover_otps", ["booking_id"], schema=C)
    op.create_table(
        "cancellations",
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.bookings.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("by_id", postgresql.UUID(), nullable=False),
        sa.Column("by_role", sa.String(10), nullable=False),
        sa.Column("note", sa.Text(), nullable=False),
        _ts("at", False),
        sa.Column("rating_stars", sa.SmallInteger()),
        sa.Column("rating_comment", sa.Text()),
        _ts("rated_at"),
        sa.CheckConstraint("rating_stars BETWEEN 1 AND 5", name="rating_stars"),
        schema=C,
    )
    op.create_index("ix_cancellations_by_id", "cancellations", ["by_id"], schema=C)


def downgrade() -> None:
    for table in (
        "cancellations",
        "handover_otps",
        "handover_photos",
        "booking_events",
        "bookings",
    ):
        op.drop_table(table, schema=C)
