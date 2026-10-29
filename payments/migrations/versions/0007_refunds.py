"""refunds

Revision ID: p0007
Revises: p0006
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0007"
down_revision: str | None = "p0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "refunds",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("payment_id", postgresql.UUID(), nullable=False),
        sa.Column("amount_paise", sa.BigInteger(), nullable=False),
        sa.Column("ruling_ref", postgresql.UUID()),
        sa.Column("method", sa.String(10), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("razorpay_refund_id", sa.String(50), unique=True),
        sa.Column("marked_by", postgresql.UUID()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("amount_paise > 0", name="amount_positive"),
        schema="payments",
    )
    op.create_index("ix_refunds_payment_id", "refunds", ["payment_id"], schema="payments")


def downgrade() -> None:
    op.drop_table("refunds", schema="payments")
