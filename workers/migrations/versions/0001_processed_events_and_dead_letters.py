"""processed events and dead letters

Revision ID: w0001
Revises:
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "w0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "processed_events",
        sa.Column("consumer", sa.String(50), primary_key=True),
        sa.Column("event_id", postgresql.UUID(), primary_key=True),
        sa.Column("outcome", sa.String(20), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        schema="workers",
    )
    op.create_table(
        "dead_letters",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("consumer", sa.String(50), nullable=False),
        sa.Column("topic", sa.String(100), nullable=False),
        sa.Column("event_id", postgresql.UUID()),
        sa.Column("type", sa.String(100)),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.Column("error", sa.Text(), nullable=False),
        sa.Column("failed_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        schema="workers",
    )


def downgrade() -> None:
    op.drop_table("dead_letters", schema="workers")
    op.drop_table("processed_events", schema="workers")
