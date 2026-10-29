"""appeals, rulings and trust penalties

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-29
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0011"
down_revision: str | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

C = "core"


def _ts(name: str, nullable: bool = True) -> sa.Column:
    return sa.Column(name, sa.DateTime(timezone=True), nullable=nullable)


def upgrade() -> None:
    op.create_table(
        "appeals",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "booking_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.bookings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("filed_by_id", postgresql.UUID(), nullable=False),
        sa.Column("filed_by_role", sa.String(10), nullable=False),
        sa.Column("reason", sa.String(30), nullable=False),
        sa.Column("notes", sa.Text(), nullable=False),
        sa.Column("photo_keys", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("previous_status", sa.String(20), nullable=False),
        sa.Column("status", sa.String(10), nullable=False),
        _ts("created_at", False),
        schema=C,
    )
    op.create_index("ix_appeals_booking_id", "appeals", ["booking_id"], schema=C)
    op.create_index("ix_appeals_filed_by_id", "appeals", ["filed_by_id"], schema=C)
    op.create_index("ix_appeals_status", "appeals", ["status"], schema=C)
    op.create_table(
        "rulings",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "appeal_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{C}.appeals.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("ruled_by", postgresql.UUID(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("charge_paise", sa.BigInteger()),
        sa.Column("refund_paise", sa.BigInteger()),
        sa.Column("refund_id", postgresql.UUID()),
        sa.Column("trust_penalty", postgresql.JSONB()),
        sa.Column("remove_listing", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("account_action", postgresql.JSONB()),
        sa.Column("overrules", postgresql.UUID()),
        _ts("ruled_at", False),
        schema=C,
    )
    op.create_index("ix_rulings_appeal_id", "rulings", ["appeal_id"], schema=C)
    op.create_table(
        "trust_penalties",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("account_id", postgresql.UUID(), nullable=False),
        sa.Column("role", sa.String(10), nullable=False),
        sa.Column("points", sa.SmallInteger(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("by", postgresql.UUID(), nullable=False),
        sa.Column("ruling_id", postgresql.UUID()),
        _ts("created_at", False),
        _ts("revoked_at"),
        sa.CheckConstraint("points BETWEEN 1 AND 100", name="points"),
        schema=C,
    )
    op.create_index("ix_trust_penalties_account_id", "trust_penalties", ["account_id"], schema=C)


def downgrade() -> None:
    op.drop_table("trust_penalties", schema=C)
    op.drop_table("rulings", schema=C)
    op.drop_table("appeals", schema=C)
