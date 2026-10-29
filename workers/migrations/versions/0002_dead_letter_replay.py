"""record when a dead letter was replayed

Revision ID: w0002
Revises: w0001
Create Date: 2026-10-29
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "w0002"
down_revision: str | None = "w0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "dead_letters", sa.Column("replayed_at", sa.DateTime(timezone=True)), schema="workers"
    )


def downgrade() -> None:
    op.drop_column("dead_letters", "replayed_at", schema="workers")
