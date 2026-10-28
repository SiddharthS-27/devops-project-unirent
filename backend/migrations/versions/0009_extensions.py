"""extensions and the frozen late fee

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("bookings", sa.Column("late_fee_paise", sa.BigInteger()), schema="core")
    op.create_table(
        "extensions",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey("core.bookings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("old_end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("new_end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(10), nullable=False),
        sa.Column("amount_paise", sa.BigInteger(), nullable=False),
        sa.Column("pay_in_cash_at_return", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("decided_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("new_end_at > old_end_at", name="later"),
        schema="core",
    )
    op.create_index("ix_extensions_booking_id", "extensions", ["booking_id"], schema="core")


def downgrade() -> None:
    op.drop_table("extensions", schema="core")
    op.drop_column("bookings", "late_fee_paise", schema="core")
