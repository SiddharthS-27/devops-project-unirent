"""HTTP routes owned by the payments package. The backend mounts them under /api/v1."""

import hmac
import json
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Header, Request
from sqlalchemy import select
from unirent_security import AdminAccount, CurrentAccount, audit, require_owner
from unirent_security.errors import ApiError

from unirent_payments import (
    late_fees,
    linked_accounts,
    payments,
    reconciliation,
    refunds,
    webhooks,
)
from unirent_payments.config import get_settings
from unirent_payments.db import SessionDep
from unirent_payments.models import LinkedAccount, ReconciliationRun
from unirent_payments.payments import PaymentView
from unirent_payments.schemas import (
    LateFeeRuleOut,
    MismatchOut,
    PaymentOut,
    PayoutAccountIn,
    PayoutAccountOut,
    ReconciliationReport,
    ReconciliationRunIn,
    ReconciliationRunOut,
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


async def _report(session, run) -> ReconciliationReport:
    rows = await reconciliation.mismatches(session, run.id)
    return ReconciliationReport(
        **ReconciliationRunOut.model_validate(run, from_attributes=True).model_dump(),
        mismatches=[MismatchOut.model_validate(m, from_attributes=True) for m in rows],
    )


@router.get("/admin/reconciliation/runs", response_model=list[ReconciliationRunOut])
async def reconciliation_runs(admin: AdminAccount, session: SessionDep):
    rows = await session.scalars(
        select(ReconciliationRun).order_by(ReconciliationRun.started_at.desc()).limit(60)
    )
    return [ReconciliationRunOut.model_validate(r, from_attributes=True) for r in rows]


@router.get("/admin/reconciliation/runs/{run_id}", response_model=ReconciliationReport)
async def reconciliation_report(run_id: uuid.UUID, admin: AdminAccount, session: SessionDep):
    run = await session.get(ReconciliationRun, run_id)
    if run is None:
        raise ApiError(404, "NOT_FOUND", "Reconciliation run not found")
    return await _report(session, run)


@router.post("/admin/reconciliation/run", response_model=ReconciliationReport)
async def run_reconciliation_now(
    body: ReconciliationRunIn, admin: AdminAccount, session: SessionDep
):
    """Ledger against Razorpay payments, transfers and refunds for one IST day."""
    run = await reconciliation.run(body.day, triggered_by=str(admin.id))
    await audit.record(admin, "admin.reconciliation_run", audit.target("reconciliation", run.id))
    return await _report(session, run)


async def _service_token(
    service_token: Annotated[str | None, Header(alias="X-Service-Token")] = None,
) -> None:
    expected = get_settings().service_token
    if not service_token or not hmac.compare_digest(service_token, expected):
        raise ApiError(401, "SERVICE_TOKEN_REQUIRED", "Internal route")


internal_router = APIRouter(
    prefix="/internal", tags=["internal"], dependencies=[Depends(_service_token)]
)


@internal_router.post("/reconciliation/run", response_model=ReconciliationRunOut)
async def nightly_reconciliation(body: ReconciliationRunIn | None = None):
    """The workers' nightly trigger (02:00 IST): checks yesterday."""
    run = await reconciliation.run(body.day if body else None)
    return ReconciliationRunOut.model_validate(run, from_attributes=True)


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
