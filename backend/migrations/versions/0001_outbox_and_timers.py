"""outbox and timers

Revision ID: 0001
Revises:
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


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
        schema="core",
    )
    op.create_index(
        "ix_outbox_unsent",
        "outbox",
        ["occurred_at"],
        schema="core",
        postgresql_where=sa.text("sent_at IS NULL"),
    )
    op.create_table(
        "timers",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("kind", sa.String(50), nullable=False),
        sa.Column("ref_id", postgresql.UUID(), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("payload", postgresql.JSONB(), server_default="{}", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("fired_at", sa.DateTime(timezone=True)),
        sa.Column("cancelled_at", sa.DateTime(timezone=True)),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        schema="core",
    )
    op.create_index(
        "ix_timers_pending",
        "timers",
        ["due_at"],
        schema="core",
        postgresql_where=sa.text("fired_at IS NULL AND cancelled_at IS NULL"),
    )
    op.create_index("ix_timers_ref", "timers", ["ref_id", "kind"], schema="core")


def downgrade() -> None:
    op.drop_table("timers", schema="core")
    op.drop_table("outbox", schema="core")
