"""late-fee rules, with the starting rule

Revision ID: p0006
Revises: p0005
Create Date: 2026-10-28
"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0006"
down_revision: str | None = "p0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    rules = op.create_table(
        "late_fee_rules",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("version", sa.Integer(), nullable=False, unique=True),
        sa.Column("grace_minutes", sa.Integer(), nullable=False),
        sa.Column("base_fee_paise", sa.BigInteger(), nullable=False),
        sa.Column("hourly_percent_bp", sa.Integer(), nullable=False),
        sa.Column("effective_from", sa.DateTime(timezone=True), nullable=False),
        sa.Column("set_by", postgresql.UUID()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("grace_minutes >= 0", name="grace"),
        sa.CheckConstraint("base_fee_paise >= 0", name="base"),
        sa.CheckConstraint("hourly_percent_bp BETWEEN 0 AND 10000", name="percent"),
        schema="payments",
    )
    # The product plan's example rule: 30 minutes' grace, then ₹10 plus 2% an hour.
    now = datetime(2026, 10, 1, tzinfo=UTC)
    op.bulk_insert(
        rules,
        [
            {
                "id": str(uuid.uuid4()),
                "version": 1,
                "grace_minutes": 30,
                "base_fee_paise": 1000,
                "hourly_percent_bp": 200,
                "effective_from": now,
                "set_by": None,
                "created_at": now,
            }
        ],
    )


def downgrade() -> None:
    op.drop_table("late_fee_rules", schema="payments")
