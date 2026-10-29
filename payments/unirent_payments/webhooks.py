"""Checkout verification and Razorpay webhooks.

Both paths are checked with HMAC-SHA256: Checkout's signature over
"order_id|payment_id" with the key secret, webhooks over the raw body with the
webhook secret. Webhooks are recorded by event ID, so replays do nothing, and
every handler is a no-op when the payment is already where it should be."""

import hashlib
import hmac
import logging
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security.errors import ApiError

from unirent_payments import payments, refunds
from unirent_payments.config import get_settings
from unirent_payments.models import Payment, WebhookEvent

log = logging.getLogger(__name__)


def _hmac(secret: str, message: bytes) -> str:
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def checkout_signature_valid(order_id: str, payment_id: str, signature: str) -> bool:
    expected = _hmac(get_settings().razorpay_key_secret, f"{order_id}|{payment_id}".encode())
    return hmac.compare_digest(expected, signature)


def webhook_signature_valid(body: bytes, signature: str | None) -> bool:
    if not signature:
        return False
    return hmac.compare_digest(_hmac(get_settings().razorpay_webhook_secret, body), signature)


async def verify_checkout(
    session: AsyncSession, payment: Payment, order_id: str, payment_id: str, signature: str
) -> None:
    if payment.method != "upi" or payment.razorpay_order_id != order_id:
        raise ApiError(422, "ORDER_MISMATCH", "That order doesn't belong to this payment")
    if not checkout_signature_valid(order_id, payment_id, signature):
        raise ApiError(400, "INVALID_SIGNATURE", "The payment signature is not valid")
    await payments.capture(session, payment, payment_id)


async def _by_order(session: AsyncSession, order_id: str | None) -> Payment | None:
    if not order_id:
        return None
    return await session.scalar(
        select(Payment).where(Payment.razorpay_order_id == order_id).with_for_update()
    )


async def _payment_captured(session: AsyncSession, entity: dict[str, Any]) -> None:
    payment = await _by_order(session, entity.get("order_id"))
    if payment is None:
        log.warning(
            "captured payment for an unknown order", extra={"order": entity.get("order_id")}
        )
        return
    if entity.get("amount") != payment.amount_paise:
        log.warning(
            "captured amount differs",
            extra={"payment": str(payment.id), "razorpay_amount": entity.get("amount")},
        )
    await payments.capture(session, payment, entity["id"])


async def _payment_failed(session: AsyncSession, entity: dict[str, Any]) -> None:
    payment = await _by_order(session, entity.get("order_id"))
    if payment is not None:
        await payments.fail(session, payment, entity.get("error_description") or "failed")


async def _transfer_processed(session: AsyncSession, entity: dict[str, Any]) -> None:
    payment = await session.scalar(
        select(Payment).where(Payment.razorpay_payment_id == entity.get("source")).with_for_update()
    )
    if payment is not None:
        payment.transfer_id = entity["id"]
        payment.transfer_status = entity.get("status", "processed")


async def _refund_processed(session: AsyncSession, entity: dict[str, Any]) -> None:
    await refunds.refund_processed(session, entity["id"])


HANDLERS = {
    "payment.captured": ("payment", _payment_captured),
    "payment.failed": ("payment", _payment_failed),
    "transfer.processed": ("transfer", _transfer_processed),
    "refund.processed": ("refund", _refund_processed),
}


async def handle(session: AsyncSession, event_id: str | None, event: dict[str, Any]) -> str:
    """Apply one webhook. Returns 'processed', 'duplicate' or 'ignored'."""
    name = event.get("event", "")
    if event_id:
        inserted = await session.execute(
            insert(WebhookEvent)
            .values(event_id=event_id, event=name, received_at=datetime.now(UTC), payload=event)
            .on_conflict_do_nothing()
            .returning(WebhookEvent.event_id)
        )
        if inserted.scalar() is None:
            return "duplicate"
    handler = HANDLERS.get(name)
    if handler is None:
        return "ignored"
    entity_kind, fn = handler
    entity = event.get("payload", {}).get(entity_kind, {}).get("entity", {})
    await fn(session, entity)
    return "processed"
