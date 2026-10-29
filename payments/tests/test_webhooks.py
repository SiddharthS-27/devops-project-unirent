import hashlib
import hmac
import json
import uuid

import httpx
import pytest
import unirent_security.db
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from sqlalchemy import select
from unirent_security.errors import ApiError
from unirent_security.models import Account
from unirent_security.tokens import issue_access_token

from tests.fake_razorpay import FakeRazorpay
from tests.helpers import ready_payee
from unirent_payments import db, ledger
from unirent_payments.api import router, webhook_router
from unirent_payments.config import get_settings
from unirent_payments.models import LedgerEntry, OutboxEvent
from unirent_payments.payments import payment_status, start_payment
from unirent_payments.razorpay_client import RazorpayClient, use_client


@pytest.fixture
async def env(session):
    fake = FakeRazorpay()
    use_client(RazorpayClient(transport=fake.transport()))
    app = FastAPI()

    @app.exception_handler(ApiError)
    async def handle(_, exc: ApiError):
        return JSONResponse({"error": {"code": exc.code}}, status_code=exc.status_code)

    app.include_router(router)
    app.include_router(webhook_router)
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as client:
        yield fake, client
    use_client(None)
    await db.reset()
    await unirent_security.db.reset()


def _auth(account_id: uuid.UUID) -> dict:
    account = Account(id=account_id, email="p@college.edu", role="student", status="active")
    return {"Authorization": f"Bearer {issue_access_token(account)}"}


def _sign(body: bytes) -> str:
    secret = get_settings().razorpay_webhook_secret.encode()
    return hmac.new(secret, body, hashlib.sha256).hexdigest()


def _checkout_signature(order_id: str, payment_id: str) -> str:
    secret = get_settings().razorpay_key_secret.encode()
    return hmac.new(secret, f"{order_id}|{payment_id}".encode(), hashlib.sha256).hexdigest()


async def _webhook(client, event: str, entity_kind: str, entity: dict, event_id=None, sign=True):
    body = json.dumps({"event": event, "payload": {entity_kind: {"entity": entity}}}).encode()
    headers = {
        "x-razorpay-signature": _sign(body) if sign else "0" * 64,
        "x-razorpay-event-id": event_id or uuid.uuid4().hex,
        "content-type": "application/json",
    }
    return await client.post("/payments/webhooks/razorpay", content=body, headers=headers)


async def _upi(fake):
    payee, _ = await ready_payee()
    booking, payer = uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 30000, "upi", uuid.uuid4().hex)
    paid = fake.pay(p.checkout["order_id"])
    return p, paid, payer


async def _verify(client, p, paid, payer):
    return await client.post(
        f"/payments/{p.id}/verify",
        json={
            "razorpay_order_id": paid["order_id"],
            "razorpay_payment_id": paid["id"],
            "razorpay_signature": _checkout_signature(paid["order_id"], paid["id"]),
        },
        headers=_auth(payer),
    )


async def _ledger_lines(session, payment_id) -> int:
    rows = await session.scalars(select(LedgerEntry).where(LedgerEntry.payment_id == payment_id))
    return len(list(rows))


@pytest.mark.parametrize("webhook_first", [False, True])
async def test_verify_and_webhook_in_either_order_capture_once(env, session, webhook_first):
    fake, client = env
    p, paid, payer = await _upi(fake)
    if webhook_first:
        await _webhook(client, "payment.captured", "payment", paid)
    r = await _verify(client, p, paid, payer)
    assert r.status_code == 200 and r.json()["status"] == "captured"
    if not webhook_first:
        r = await _webhook(client, "payment.captured", "payment", paid)
        assert r.json()["status"] == "processed"
    assert await _ledger_lines(session, p.id) == 2
    events = await session.scalars(
        select(OutboxEvent).where(OutboxEvent.aggregate_id == str(p.booking_ref))
    )
    assert [e.type for e in events] == ["PaymentCaptured"]


async def test_replayed_webhook_does_nothing(env, session):
    fake, client = env
    p, paid, _ = await _upi(fake)
    event_id = f"evt_{uuid.uuid4().hex[:14]}"
    first = await _webhook(client, "payment.captured", "payment", paid, event_id=event_id)
    again = await _webhook(client, "payment.captured", "payment", paid, event_id=event_id)
    assert first.json()["status"] == "processed" and again.json()["status"] == "duplicate"
    assert await _ledger_lines(session, p.id) == 2


async def test_bad_signatures_are_rejected(env):
    fake, client = env
    p, paid, payer = await _upi(fake)
    r = await _webhook(client, "payment.captured", "payment", paid, sign=False)
    assert r.status_code == 400 and r.json()["error"]["code"] == "INVALID_SIGNATURE"
    r = await client.post(
        f"/payments/{p.id}/verify",
        json={
            "razorpay_order_id": paid["order_id"],
            "razorpay_payment_id": paid["id"],
            "razorpay_signature": "f" * 64,
        },
        headers=_auth(payer),
    )
    assert r.status_code == 400
    assert (await payment_status(p.booking_ref, "rent")).status == "pending"


async def test_only_the_payer_can_verify(env):
    fake, client = env
    p, paid, _ = await _upi(fake)
    r = await _verify(client, p, paid, uuid.uuid4())
    assert r.status_code == 404


async def test_failed_payment_lets_the_payer_retry(env):
    fake, client = env
    payee, _ = await ready_payee()
    booking, payer = uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 30000, "upi", "k1")
    failed = fake.pay(p.checkout["order_id"], status="failed")
    await _webhook(client, "payment.failed", "payment", failed)
    assert await payment_status(booking, "rent") is None
    retry = await start_payment(booking, "rent", payer, payee, 30000, "upi", "k2")
    assert retry.id != p.id and retry.status == "pending"


async def test_transfer_is_recorded(env, session):
    fake, client = env
    p, paid, payer = await _upi(fake)
    await _verify(client, p, paid, payer)
    transfer = paid["transfers"][0] | {"source": paid["id"], "status": "processed"}
    await _webhook(client, "transfer.processed", "transfer", transfer)
    from unirent_payments.models import Payment

    row = await session.get(Payment, p.id)
    await session.refresh(row)
    assert row.transfer_id == transfer["id"]
    assert (await ledger.trial_balance(session)).balanced
