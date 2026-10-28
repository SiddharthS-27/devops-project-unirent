"""UPI payments: a Razorpay Order that carries a transfer of the full amount to
the payee's linked account. The platform takes no fee and holds no money."""

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security.errors import ApiError

from unirent_payments.config import get_settings
from unirent_payments.linked_accounts import READY, get_linked
from unirent_payments.models import Payment
from unirent_payments.razorpay_client import razorpay

DESCRIPTIONS = {
    "rent": "Rent",
    "extension": "Extension",
    "return_charges": "Late fee and charges",
    "sale": "Purchase",
}


async def create_order(session: AsyncSession, payment: Payment) -> dict[str, Any]:
    linked = await get_linked(session, payment.payee_id)
    if linked is None or linked.status != READY:
        raise ApiError(
            409, "PAYEE_NOT_PAYOUT_READY", "The owner can't receive UPI payments; pay in cash"
        )
    order = await razorpay().create_order(
        {
            "amount": payment.amount_paise,
            "currency": "INR",
            "receipt": str(payment.id)[:40],
            "notes": {"booking": str(payment.booking_ref), "purpose": payment.purpose},
            "transfers": [
                {
                    "account": linked.razorpay_account_id,
                    "amount": payment.amount_paise,
                    "currency": "INR",
                    "notes": {"payment": str(payment.id)},
                    "on_hold": False,
                }
            ],
        }
    )
    payment.razorpay_order_id = order["id"]
    return order


def checkout(payment: Payment) -> dict[str, Any] | None:
    """What Razorpay Checkout needs; only while a UPI payment is pending."""
    if payment.method != "upi" or payment.status != "pending" or not payment.razorpay_order_id:
        return None
    settings = get_settings()
    return {
        "key_id": settings.razorpay_key_id,
        "order_id": payment.razorpay_order_id,
        "amount_paise": payment.amount_paise,
        "currency": "INR",
        "name": settings.checkout_name,
        "description": DESCRIPTIONS[payment.purpose],
        "prefill_email": None,
        "prefill_contact": None,
    }


async def captured_on_razorpay(payment: Payment) -> dict[str, Any] | None:
    """The captured Razorpay payment for this order, if the payer already paid."""
    if not payment.razorpay_order_id:
        return None
    for item in await razorpay().order_payments(payment.razorpay_order_id):
        if item.get("status") == "captured":
            return item
    return None
