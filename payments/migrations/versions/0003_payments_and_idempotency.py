"""payments and idempotency records

Revision ID: p0003
Revises: p0002
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p0003"
down_revision: str | None = "p0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

S = "payments"


def upgrade() -> None:
    op.create_table(
        "payments",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("booking_ref", postgresql.UUID(), nullable=False),
        sa.Column("purpose", sa.String(20), nullable=False),
        sa.Column("purpose_ref", postgresql.UUID()),
        sa.Column("payer_id", postgresql.UUID(), nullable=False),
        sa.Column("payee_id", postgresql.UUID(), nullable=False),
        sa.Column("amount_paise", sa.BigInteger(), nullable=False),
        sa.Column("items", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("method", sa.String(10), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("idempotency_key", sa.String(100), nullable=False),
        sa.Column("razorpay_order_id", sa.String(50), unique=True),
        sa.Column("razorpay_payment_id", sa.String(50), unique=True),
        sa.Column("transfer_id", sa.String(50)),
        sa.Column("transfer_status", sa.String(20)),
        sa.Column("failure_reason", sa.Text()),
        sa.Column("refunded_paise", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("marked_by", postgresql.UUID()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("payer_id", "idempotency_key"),
        sa.CheckConstraint("amount_paise > 0", name="amount_positive"),
        sa.CheckConstraint(
            "purpose IN ('rent', 'extension', 'return_charges', 'sale')", name="purpose"
        ),
        sa.CheckConstraint("method IN ('upi', 'cash')", name="method"),
        schema=S,
    )
    op.create_index("ix_payments_booking_ref", "payments", ["booking_ref"], schema=S)
    op.create_index("ix_payments_payer_id", "payments", ["payer_id"], schema=S)
    op.create_index("ix_payments_payee_id", "payments", ["payee_id"], schema=S)
    op.execute(
        "CREATE UNIQUE INDEX uq_payments_one_live ON payments.payments (booking_ref, purpose, "
        "coalesce(purpose_ref, '00000000-0000-0000-0000-000000000000'::uuid)) "
        "WHERE status <> 'failed'"
    )
    op.create_table(
        "idempotency_records",
        sa.Column("scope", sa.String(64), primary_key=True),
        sa.Column("key", sa.String(100), primary_key=True),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("status_code", sa.Integer(), nullable=False),
        sa.Column("response_body", sa.Text(), nullable=False),
        sa.Column("content_type", sa.String(100)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        schema=S,
    )
    op.create_index(
        "ix_idempotency_records_expires_at", "idempotency_records", ["expires_at"], schema=S
    )


def downgrade() -> None:
    op.drop_table("idempotency_records", schema=S)
    op.drop_table("payments", schema=S)
