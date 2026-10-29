"""reconciliation runs and mismatches

Revision ID: p0008
Revises: p0007
Create Date: 2026-10-28
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0008"
down_revision: str | None = "p0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

S = "payments"


def upgrade() -> None:
    op.create_table(
        "reconciliation_runs",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("triggered_by", sa.String(50), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("totals", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
        sa.Column("error", sa.Text()),
        schema=S,
    )
    op.create_index("ix_reconciliation_runs_day", "reconciliation_runs", ["day"], schema=S)
    op.create_table(
        "reconciliation_mismatches",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("run_id", postgresql.UUID(), nullable=False),
        sa.Column("kind", sa.String(30), nullable=False),
        sa.Column("reference", sa.String(100), nullable=False),
        sa.Column("payment_id", postgresql.UUID()),
        sa.Column("ledger_amount_paise", sa.BigInteger()),
        sa.Column("razorpay_amount_paise", sa.BigInteger()),
        sa.Column("ledger_status", sa.String(20)),
        sa.Column("razorpay_status", sa.String(20)),
        schema=S,
    )
    op.create_index(
        "ix_reconciliation_mismatches_run_id", "reconciliation_mismatches", ["run_id"], schema=S
    )


def downgrade() -> None:
    op.drop_table("reconciliation_mismatches", schema=S)
    op.drop_table("reconciliation_runs", schema=S)
