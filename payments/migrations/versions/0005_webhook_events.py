"""webhook events

Revision ID: p0005
Revises: p0004
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0005"
down_revision: str | None = "p0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "webhook_events",
        sa.Column("event_id", sa.String(64), primary_key=True),
        sa.Column("event", sa.String(50), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        schema="payments",
    )


def downgrade() -> None:
    op.drop_table("webhook_events", schema="payments")
