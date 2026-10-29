"""profiles

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "profiles",
        sa.Column("account_id", postgresql.UUID(), primary_key=True),
        sa.Column("full_name", sa.String(200), nullable=False),
        sa.Column("photo_key", sa.String(300)),
        sa.Column("roll_number", sa.String(50), nullable=False),
        sa.Column("department", sa.String(100), nullable=False),
        sa.Column("year", sa.SmallInteger(), nullable=False),
        sa.Column("residence_type", sa.String(20), nullable=False),
        sa.Column("hostel_name", sa.String(100)),
        sa.Column("room_number", sa.String(20)),
        sa.Column("home_address", sa.Text()),
        sa.Column("terms_version", sa.String(20)),
        sa.Column("terms_accepted_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("year BETWEEN 1 AND 6", name="year"),
        sa.CheckConstraint("residence_type IN ('hostel', 'day_scholar')", name="residence_type"),
        schema="core",
    )


def downgrade() -> None:
    op.drop_table("profiles", schema="core")
