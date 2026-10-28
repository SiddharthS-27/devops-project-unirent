"""reviews

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0010"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "reviews",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey("core.bookings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("reviewer_id", postgresql.UUID(), nullable=False),
        sa.Column("reviewee_id", postgresql.UUID(), nullable=False),
        sa.Column("review_type", sa.String(20), nullable=False),
        sa.Column("reviewee_role", sa.String(10), nullable=False),
        sa.Column("ratings", postgresql.JSONB(), nullable=False),
        sa.Column("overall", sa.Numeric(3, 2), nullable=False),
        sa.Column("comment", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revealed_at", sa.DateTime(timezone=True)),
        sa.Column("removed_at", sa.DateTime(timezone=True)),
        sa.Column("removed_reason", sa.Text()),
        sa.UniqueConstraint("booking_id", "reviewer_id"),
        sa.CheckConstraint("overall BETWEEN 1 AND 5", name="overall"),
        sa.CheckConstraint("reviewee_role IN ('lender', 'renter')", name="reviewee_role"),
        sa.CheckConstraint(
            "review_type IN ('renter', 'lender', 'renter_sale', 'lender_sale', 'cancellation')",
            name="review_type",
        ),
        schema="core",
    )
    for column in ("booking_id", "reviewer_id", "reviewee_id"):
        op.create_index(f"ix_reviews_{column}", "reviews", [column], schema="core")


def downgrade() -> None:
    op.drop_table("reviews", schema="core")
