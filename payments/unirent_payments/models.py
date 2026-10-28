import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import BigInteger, DateTime, Index, Integer, String, Text, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from unirent_payments.db import Base


class OutboxEvent(Base):
    """payments.events waiting for the workers' relay. Same shape as core.outbox."""

    __tablename__ = "outbox"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    topic: Mapped[str] = mapped_column(String(100))
    type: Mapped[str] = mapped_column(String(100))
    version: Mapped[int] = mapped_column(Integer, default=1)
    aggregate_id: Mapped[str] = mapped_column(String(64))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB)
    producer: Mapped[str] = mapped_column(String(50), default="payments")
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        Index("ix_outbox_unsent", "occurred_at", postgresql_where=text("sent_at IS NULL")),
    )


class LinkedAccount(Base):
    """An owner's Razorpay Route linked account. Bank details go straight to
    Razorpay; only the account ID and its status are kept."""

    __tablename__ = "linked_accounts"

    account_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True)
    razorpay_account_id: Mapped[str] = mapped_column(String(50), unique=True)
    route_product_id: Mapped[str | None] = mapped_column(String(50))
    status: Mapped[str] = mapped_column(String(30))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


LIVE_STATUSES = ("created", "pending", "captured", "marked_paid", "refunded", "partly_refunded")
PAID_STATUSES = ("captured", "marked_paid", "refunded", "partly_refunded")


class Payment(Base):
    """One attempt to pay for one thing. At most one live (not failed) payment
    exists per booking, purpose and purpose_ref, so nothing is paid twice."""

    __tablename__ = "payments"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    booking_ref: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    purpose: Mapped[str] = mapped_column(String(20))  # rent, extension, return_charges, sale
    # Which extension an extension payment is for; null otherwise.
    purpose_ref: Mapped[uuid.UUID | None] = mapped_column(UUID)
    payer_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    payee_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    amount_paise: Mapped[int] = mapped_column(BigInteger)
    items: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, default=list)
    method: Mapped[str] = mapped_column(String(10))  # upi or cash
    status: Mapped[str] = mapped_column(String(20))
    idempotency_key: Mapped[str] = mapped_column(String(100))
    razorpay_order_id: Mapped[str | None] = mapped_column(String(50), unique=True)
    razorpay_payment_id: Mapped[str | None] = mapped_column(String(50), unique=True)
    transfer_id: Mapped[str | None] = mapped_column(String(50))
    transfer_status: Mapped[str | None] = mapped_column(String(20))
    failure_reason: Mapped[str | None] = mapped_column(Text)
    refunded_paise: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
    marked_by: Mapped[uuid.UUID | None] = mapped_column(UUID)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("payer_id", "idempotency_key"),
        Index(
            "uq_payments_one_live",
            "booking_ref",
            "purpose",
            text("coalesce(purpose_ref, '00000000-0000-0000-0000-000000000000'::uuid)"),
            unique=True,
            postgresql_where=text("status <> 'failed'"),
        ),
    )


class IdempotencyRecord(Base):
    """The first response to a request with an Idempotency-Key, replayed for 24 hours."""

    __tablename__ = "idempotency_records"

    scope: Mapped[str] = mapped_column(String(64), primary_key=True)
    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    request_hash: Mapped[str] = mapped_column(String(64))
    status_code: Mapped[int] = mapped_column(Integer)
    response_body: Mapped[str] = mapped_column(Text)
    content_type: Mapped[str | None] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class LedgerEntry(Base):
    """One side of a double-entry posting. Append only: corrections are new
    entries. Every transaction's debits equal its credits."""

    __tablename__ = "ledger_entries"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    txn_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    kind: Mapped[str] = mapped_column(String(30))  # payment, cash_payment, refund, cash_refund
    ledger_account: Mapped[str] = mapped_column(String(80), index=True)
    direction: Mapped[str] = mapped_column(String(6))  # debit or credit
    amount_paise: Mapped[int] = mapped_column(BigInteger)
    payment_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    refund_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    booking_ref: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    channel: Mapped[str] = mapped_column(String(10))  # upi or cash
    memo: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class WebhookEvent(Base):
    """Every Razorpay webhook delivery we accepted, by Razorpay's event ID, so a
    replayed delivery is recognised and does nothing."""

    __tablename__ = "webhook_events"

    event_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    event: Mapped[str] = mapped_column(String(50))
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB)


class LateFeeRule(Base):
    """The platform's late-fee rule. Versioned: a change adds a row, and each
    booking keeps the rule that was current when it was approved."""

    __tablename__ = "late_fee_rules"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    version: Mapped[int] = mapped_column(Integer, unique=True)
    grace_minutes: Mapped[int] = mapped_column(Integer)
    base_fee_paise: Mapped[int] = mapped_column(BigInteger)
    hourly_percent_bp: Mapped[int] = mapped_column(Integer)  # basis points: 200 = 2%
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    set_by: Mapped[uuid.UUID | None] = mapped_column(UUID)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Refund(Base):
    """Money back to the payer after a ruling. UPI refunds go through Razorpay and
    reverse the transfer from the owner's linked account; cash refunds are
    handed back in person and marked done by the owner."""

    __tablename__ = "refunds"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    payment_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    amount_paise: Mapped[int] = mapped_column(BigInteger)
    ruling_ref: Mapped[uuid.UUID | None] = mapped_column(UUID)
    method: Mapped[str] = mapped_column(String(10))
    # upi: pending, processed, failed. cash: cash_pending, cash_done.
    status: Mapped[str] = mapped_column(String(20))
    razorpay_refund_id: Mapped[str | None] = mapped_column(String(50), unique=True)
    marked_by: Mapped[uuid.UUID | None] = mapped_column(UUID)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
