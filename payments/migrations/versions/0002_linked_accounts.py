"""linked accounts

Revision ID: p0002
Revises: p0001
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0002"
down_revision: str | None = "p0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "linked_accounts",
        sa.Column("account_id", postgresql.UUID(), primary_key=True),
        sa.Column("razorpay_account_id", sa.String(50), nullable=False, unique=True),
        sa.Column("route_product_id", sa.String(50)),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        schema="payments",
    )


def downgrade() -> None:
    op.drop_table("linked_accounts", schema="payments")
