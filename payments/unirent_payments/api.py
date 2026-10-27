"""HTTP routes owned by the payments package. The backend mounts them under /api/v1."""

from fastapi import APIRouter
from unirent_security import CurrentAccount, audit
from unirent_security.errors import ApiError

from unirent_payments import linked_accounts
from unirent_payments.db import SessionDep
from unirent_payments.models import LinkedAccount
from unirent_payments.schemas import PayoutAccountIn, PayoutAccountOut

router = APIRouter(tags=["payments"])


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
