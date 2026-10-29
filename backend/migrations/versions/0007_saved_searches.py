"""saved searches

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "saved_searches",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("account_id", postgresql.UUID(), nullable=False),
        sa.Column("name", sa.String(100)),
        sa.Column("q", sa.String(100)),
        sa.Column("tsquery", sa.String(400)),
        sa.Column("category", sa.String(20)),
        sa.Column("kind", sa.String(10)),
        sa.Column("min_price_paise", sa.BigInteger()),
        sa.Column("max_price_paise", sa.BigInteger()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_viewed_at", sa.DateTime(timezone=True), nullable=False),
        schema="core",
    )
    op.create_index("ix_saved_searches_account_id", "saved_searches", ["account_id"], schema="core")


def downgrade() -> None:
    op.drop_table("saved_searches", schema="core")
