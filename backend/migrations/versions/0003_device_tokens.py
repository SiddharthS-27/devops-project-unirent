"""device tokens

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "device_tokens",
        sa.Column("token", sa.String(500), primary_key=True),
        sa.Column("account_id", postgresql.UUID(), nullable=False),
        sa.Column("platform", sa.String(10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        schema="core",
    )
    op.create_index("ix_device_tokens_account_id", "device_tokens", ["account_id"], schema="core")


def downgrade() -> None:
    op.drop_table("device_tokens", schema="core")
