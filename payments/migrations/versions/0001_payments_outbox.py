"""payments schema: outbox

Revision ID: p0001
Revises:
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

S = "payments"


def upgrade() -> None:
    op.create_table(
        "outbox",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("topic", sa.String(100), nullable=False),
        sa.Column("type", sa.String(100), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("aggregate_id", sa.String(64), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.Column("producer", sa.String(50), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True)),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("last_error", sa.Text()),
        schema=S,
    )
    op.create_index(
        "ix_outbox_unsent",
        "outbox",
        ["occurred_at"],
        schema=S,
        postgresql_where=sa.text("sent_at IS NULL"),
    )
    # The workers' relay reads and marks this table (the one cross-schema exception).
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'unirent_workers') THEN
            GRANT SELECT, UPDATE ON payments.outbox TO unirent_workers;
          END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.drop_table("outbox", schema=S)
