"""trust scores

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trust_scores",
        sa.Column("account_id", postgresql.UUID(), primary_key=True),
        sa.Column("lender_score", sa.SmallInteger()),
        sa.Column("renter_score", sa.SmallInteger()),
        sa.Column("lender_rating", sa.Numeric(3, 2)),
        sa.Column("renter_rating", sa.Numeric(3, 2)),
        sa.Column("lender_reviews", sa.Integer(), server_default="0", nullable=False),
        sa.Column("renter_reviews", sa.Integer(), server_default="0", nullable=False),
        sa.Column("completed_trades", sa.Integer(), server_default="0", nullable=False),
        sa.Column("cancellations", sa.Integer(), server_default="0", nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("lender_score BETWEEN 0 AND 100", name="lender_score"),
        sa.CheckConstraint("renter_score BETWEEN 0 AND 100", name="renter_score"),
        schema="core",
    )
    op.create_index("ix_trust_scores_lender_score", "trust_scores", ["lender_score"], schema="core")


def downgrade() -> None:
    op.drop_table("trust_scores", schema="core")
