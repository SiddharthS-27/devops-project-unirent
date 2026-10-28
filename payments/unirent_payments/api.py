"""HTTP routes owned by the payments package. The backend mounts them under /api/v1."""

import json
import uuid

from fastapi import APIRouter, Request
from unirent_security import CurrentAccount, audit, require_owner
from unirent_security.errors import ApiError

from unirent_payments import late_fees, linked_accounts, payments, refunds, webhooks
from unirent_payments.db import SessionDep
from unirent_payments.models import LinkedAccount
from unirent_payments.payments import PaymentView
from unirent_payments.schemas import (
    LateFeeRuleOut,
    PaymentOut,
    PayoutAccountIn,
    PayoutAccountOut,
    RefundOut,
    VerifyIn,
    WebhookAck,
)

router = APIRouter(tags=["payments"])
# Razorpay calls this one: no user token and no per-user rate limit.
webhook_router = APIRouter(tags=["payments"])


def payment_out(view: PaymentView) -> PaymentOut:
    return PaymentOut(
        id=view.id,
        purpose=view.purpose,  # type: ignore[arg-type]
        method=view.method,  # type: ignore[arg-type]
        status=view.status,  # type: ignore[arg-type]
        amount_paise=view.amount_paise,
        items=view.items,  # type: ignore[arg-type]
        checkout=view.checkout,  # type: ignore[arg-type]
        created_at=view.created_at,
        captured_at=view.paid_at,
    )


def _payout_out(linked: LinkedAccount | None) -> PayoutAccountOut:
    if linked is None:
        return PayoutAccountOut(status="none", ready=False)
    return PayoutAccountOut(
        status=linked.status,  # type: ignore[arg-type]
        ready=linked.status == linked_accounts.READY,
        razorpay_account_id=linked.razorpay_account_id,
        updated_at=linked.updated_at,
    )


def _students_only(account) -> None:
    if account.role != "student":
        raise ApiError(403, "STUDENTS_ONLY", "Only students have payout accounts")


@router.get("/payouts/account", response_model=PayoutAccountOut)
async def get_payout_account(account: CurrentAccount, session: SessionDep) -> PayoutAccountOut:
    return _payout_out(await linked_accounts.get_linked(session, account.id))


@router.post("/payouts/account", response_model=PayoutAccountOut, status_code=201)
async def link_payout_account(
    body: PayoutAccountIn, account: CurrentAccount, session: SessionDep
) -> PayoutAccountOut:
    """Link a Razorpay account to receive UPI payments. Required before listing."""
    _students_only(account)
    linked = await linked_accounts.link_account(session, account.id, **body.model_dump())
    await audit.record(
        account, "payout.account_linked", audit.target("account", account.id), session=session
    )
    await session.commit()
    return _payout_out(linked)


@router.post("/payouts/account/refresh", response_model=PayoutAccountOut)
async def refresh_payout_account(account: CurrentAccount, session: SessionDep) -> PayoutAccountOut:
    """Ask Razorpay for the latest activation status."""
    linked = await linked_accounts.refresh_status(session, account.id)
    await session.commit()
    return _payout_out(linked)


@router.get("/late-fee-rule", response_model=LateFeeRuleOut)
async def late_fee_rule(account: CurrentAccount) -> LateFeeRuleOut:
    """The platform rule every rent listing shows."""
    rule = await late_fees.current_late_fee_rule()
    return LateFeeRuleOut(**{k: getattr(rule, k) for k in LateFeeRuleOut.model_fields})


@router.get("/payments/{payment_id}", response_model=PaymentOut)
async def get_payment(payment_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    payment = await payments.get_payment(session, payment_id)
    require_owner(account, payment.payer_id, payment.payee_id, what="Payment")
    return payment_out(payments.view(payment, await payments.checkout_for(payment)))


@router.post("/payments/{payment_id}/verify", response_model=PaymentOut)
async def verify_payment(
    payment_id: uuid.UUID, body: VerifyIn, account: CurrentAccount, session: SessionDep
):
    """Send what Checkout returned. Verify and the webhook may arrive in either
    order; whichever comes first captures the payment."""
    payment = await payments.get_payment(session, payment_id, lock=True)
    require_owner(account, payment.payer_id, allow_staff=False, what="Payment")
    await webhooks.verify_checkout(
        session, payment, body.razorpay_order_id, body.razorpay_payment_id, body.razorpay_signature
    )
    await audit.record(
        account, "payment.verified", audit.target("payment", payment.id), session=session
    )
    await session.commit()
    return payment_out(payments.view(payment))


@router.post("/payments/{payment_id}/mark-cash-paid", response_model=PaymentOut)
async def mark_cash_paid(payment_id: uuid.UUID, account: CurrentAccount):
    """The owner (payee) taps "Mark cash received"."""
    return payment_out(await payments.mark_cash_paid(payment_id, account.id))


@router.post("/refunds/{refund_id}/mark-done", response_model=RefundOut)
async def mark_cash_refunded(refund_id: uuid.UUID, account: CurrentAccount) -> RefundOut:
    """The owner confirms a ruled cash refund was handed back."""
    refund = await refunds.mark_cash_refunded(refund_id, account.id)
    return RefundOut.model_validate(refund, from_attributes=True)


@webhook_router.post("/payments/webhooks/razorpay", response_model=WebhookAck)
async def razorpay_webhook(request: Request, session: SessionDep) -> WebhookAck:
    """Signed with X-Razorpay-Signature; replays (same event ID) do nothing."""
    body = await request.body()
    if not webhooks.webhook_signature_valid(body, request.headers.get("x-razorpay-signature")):
        raise ApiError(400, "INVALID_SIGNATURE", "The webhook signature is not valid")
    try:
        event = json.loads(body)
    except ValueError:
        raise ApiError(400, "INVALID_BODY", "The webhook body is not JSON") from None
    status = await webhooks.handle(session, request.headers.get("x-razorpay-event-id"), event)
    await session.commit()
    return WebhookAck(status=status)  # type: ignore[arg-type]
