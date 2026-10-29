"""Route linked accounts: every owner and seller links one before listing, and
rent goes straight to it."""

import uuid
from datetime import UTC, datetime

from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security.errors import ApiError

from unirent_payments import db
from unirent_payments.config import get_settings
from unirent_payments.models import LinkedAccount
from unirent_payments.razorpay_client import razorpay

# Razorpay's product activation_status values, and ours.
READY = "activated"
STATUSES = {"created", "under_review", "needs_clarification", "activated", "suspended"}


def _now() -> datetime:
    return datetime.now(UTC)


async def payout_ready(account_id: uuid.UUID) -> bool:
    """True when the owner can receive UPI payments, so they may list."""
    if not get_settings().razorpay_route:
        return True
    async with db.sessionmaker()() as session:
        linked = await session.get(LinkedAccount, account_id)
        return linked is not None and linked.status == READY


async def get_linked(session: AsyncSession, account_id: uuid.UUID) -> LinkedAccount | None:
    return await session.get(LinkedAccount, account_id)


async def link_account(
    session: AsyncSession,
    account_id: uuid.UUID,
    *,
    legal_name: str,
    email: str,
    phone: str,
    account_number: str,
    ifsc: str,
    beneficiary_name: str,
) -> LinkedAccount:
    """Create the linked account, its stakeholder and the Route product with the
    settlement bank account. Nothing about the bank account is stored here."""
    existing = await session.get(LinkedAccount, account_id, with_for_update=True)
    if existing is not None and existing.status != "suspended":
        raise ApiError(409, "PAYOUT_ACCOUNT_EXISTS", "You already linked a payout account")

    client = razorpay()
    account = await client.create_account(
        {
            "email": email,
            "phone": phone.removeprefix("+91"),
            "type": "route",
            "reference_id": str(account_id)[:20],
            "legal_business_name": legal_name,
            "business_type": "individual",
            "contact_name": legal_name,
            "profile": {
                "category": "others",
                "subcategory": "others",
                "addresses": {
                    "registered": {
                        "street1": "Campus",
                        "street2": "Campus",
                        "city": "Chennai",
                        "state": "TAMIL NADU",
                        "postal_code": "600036",
                        "country": "IN",
                    }
                },
            },
        }
    )
    await client.create_stakeholder(account["id"], {"name": legal_name, "email": email})
    product = await client.request_route_product(account["id"])
    product = await client.update_product(
        account["id"],
        product["id"],
        {
            "settlements": {
                "account_number": account_number,
                "ifsc_code": ifsc,
                "beneficiary_name": beneficiary_name,
            },
            "tnc_accepted": True,
        },
    )
    status = product.get("activation_status", "created")
    if existing is not None:
        await session.delete(existing)
        await session.flush()
    linked = LinkedAccount(
        account_id=account_id,
        razorpay_account_id=account["id"],
        route_product_id=product["id"],
        status=status if status in STATUSES else "created",
        created_at=_now(),
        updated_at=_now(),
    )
    session.add(linked)
    await session.flush()
    return linked


async def refresh_status(session: AsyncSession, account_id: uuid.UUID) -> LinkedAccount:
    linked = await session.get(LinkedAccount, account_id, with_for_update=True)
    if linked is None:
        raise ApiError(404, "NO_PAYOUT_ACCOUNT", "Link a payout account first")
    if linked.route_product_id:
        product = await razorpay().fetch_product(
            linked.razorpay_account_id, linked.route_product_id
        )
        set_status(linked, product.get("activation_status", linked.status))
    return linked


def set_status(linked: LinkedAccount, status: str) -> None:
    if status in STATUSES and status != linked.status:
        linked.status = status
        linked.updated_at = _now()
