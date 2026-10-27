"""append-only ledger

Revision ID: p0004
Revises: p0003
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0004"
down_revision: str | None = "p0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

S = "payments"


def upgrade() -> None:
    op.create_table(
        "ledger_entries",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("txn_id", postgresql.UUID(), nullable=False),
        sa.Column("kind", sa.String(30), nullable=False),
        sa.Column("ledger_account", sa.String(80), nullable=False),
        sa.Column("direction", sa.String(6), nullable=False),
        sa.Column("amount_paise", sa.BigInteger(), nullable=False),
        sa.Column("payment_id", postgresql.UUID(), nullable=False),
        sa.Column("refund_id", postgresql.UUID()),
        sa.Column("booking_ref", postgresql.UUID(), nullable=False),
        sa.Column("channel", sa.String(10), nullable=False),
        sa.Column("memo", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("amount_paise > 0", name="amount_positive"),
        sa.CheckConstraint("direction IN ('debit', 'credit')", name="direction"),
        schema=S,
    )
    for column in ("txn_id", "ledger_account", "payment_id", "booking_ref"):
        op.create_index(f"ix_ledger_entries_{column}", "ledger_entries", [column], schema=S)
    op.execute(
        """
        CREATE FUNCTION payments.refuse_change() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          RAISE EXCEPTION '% is append only', TG_TABLE_NAME;
        END $$;
        """
    )
    op.execute(
        "CREATE TRIGGER ledger_append_only BEFORE UPDATE OR DELETE ON payments.ledger_entries "
        "FOR EACH ROW EXECUTE FUNCTION payments.refuse_change()"
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'unirent_app') THEN
            REVOKE UPDATE, DELETE, TRUNCATE ON payments.ledger_entries FROM unirent_app;
          END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.drop_table("ledger_entries", schema=S)
    op.execute("DROP FUNCTION IF EXISTS payments.refuse_change()")
