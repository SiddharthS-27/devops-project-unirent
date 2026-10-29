"""support threads

Revision ID: 0012
Revises: 0011
Create Date: 2026-10-29
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0012"
down_revision: str | None = "0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "support_threads",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("account_id", postgresql.UUID(), nullable=False),
        sa.Column("booking_id", postgresql.UUID()),
        sa.Column("subject", sa.String(200), nullable=False),
        sa.Column("status", sa.String(10), nullable=False),
        sa.Column("unanswered", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        schema="core",
    )
    op.create_index(
        "ix_support_threads_account_id", "support_threads", ["account_id"], schema="core"
    )
    op.create_table(
        "support_messages",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "thread_id",
            postgresql.UUID(),
            sa.ForeignKey("core.support_threads.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("author", sa.String(10), nullable=False),
        sa.Column("author_id", postgresql.UUID()),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
        schema="core",
    )
    op.create_index(
        "ix_support_messages_thread_id", "support_messages", ["thread_id"], schema="core"
    )


def downgrade() -> None:
    op.drop_table("support_messages", schema="core")
    op.drop_table("support_threads", schema="core")
