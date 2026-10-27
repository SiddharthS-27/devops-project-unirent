"""A stand-in for the parts of Razorpay UniRent uses, for CI and keyless laptops.

It speaks the same JSON as Razorpay's API for linked accounts, orders, payments,
transfers, refunds and settlements, and sends properly signed webhooks to the
api. Extra /sim routes let tests act as the payer in Checkout and control
webhook delivery: now, late, twice, or not at all."""

import asyncio
import base64
import hashlib
import hmac
import itertools
import json
import os
import time
import uuid
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel

KEY_ID = os.environ.get("RAZORPAY_KEY_ID", "rzp_test_sim")
KEY_SECRET = os.environ.get("RAZORPAY_KEY_SECRET", "sim-key-secret")
WEBHOOK_SECRET = os.environ.get("RAZORPAY_WEBHOOK_SECRET", "sim-webhook-secret")
WEBHOOK_URL = os.environ.get("WEBHOOK_URL", "http://api:8000/api/v1/payments/webhooks/razorpay")
ACTIVATION_STATUS = os.environ.get("SIM_ACTIVATION_STATUS", "activated")

app = FastAPI(title="Razorpay simulator")
_seq = itertools.count(1)


def _id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:14]}"


class State:
    def __init__(self) -> None:
        self.accounts: dict[str, dict] = {}
        self.products: dict[str, dict] = {}
        self.orders: dict[str, dict] = {}
        self.payments: dict[str, dict] = {}
        self.transfers: dict[str, dict] = {}
        self.refunds: dict[str, dict] = {}
        self.webhooks: list[dict] = []
        self.webhooks_paused = False


state = State()


def _check_auth(request: Request) -> None:
    expected = "Basic " + base64.b64encode(f"{KEY_ID}:{KEY_SECRET}".encode()).decode()
    if request.headers.get("authorization") != expected:
        raise HTTPException(401, {"error": {"code": "BAD_REQUEST_ERROR", "description": "auth"}})


def _error(status: int, description: str) -> HTTPException:
    detail = {"error": {"code": "BAD_REQUEST_ERROR", "description": description}}
    return HTTPException(status, detail)


@app.exception_handler(HTTPException)
async def _http_error(_: Request, exc: HTTPException):
    from fastapi.responses import JSONResponse

    return JSONResponse(exc.detail, status_code=exc.status_code)


def signature(body: bytes, secret: str = WEBHOOK_SECRET) -> str:
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def checkout_signature(order_id: str, payment_id: str) -> str:
    message = f"{order_id}|{payment_id}".encode()
    return hmac.new(KEY_SECRET.encode(), message, hashlib.sha256).hexdigest()


# Webhooks --------------------------------------------------------------------


def _event(name: str, **entities: dict) -> dict:
    return {
        "entity": "event",
        "account_id": "acc_sim_platform",
        "event": name,
        "contains": list(entities),
        "payload": {kind: {"entity": entity} for kind, entity in entities.items()},
        "created_at": int(time.time()),
    }


async def _deliver(record: dict) -> None:
    body = json.dumps(record["event"]).encode()
    headers = {
        "content-type": "application/json",
        "x-razorpay-signature": record.get("signature") or signature(body),
        "x-razorpay-event-id": record["id"],
    }
    async with httpx.AsyncClient(timeout=10) as client:
        for attempt in range(3):  # Razorpay retries failed deliveries too
            try:
                response = await client.post(WEBHOOK_URL, content=body, headers=headers)
                record["deliveries"].append(response.status_code)
                if response.status_code < 300:
                    return
            except httpx.HTTPError as exc:
                record["deliveries"].append(f"error: {exc}")
            await asyncio.sleep(0.5 * (attempt + 1))


def _queue(
    event: dict, delay: float = 0.0, deliver: bool = True, bad_signature: bool = False
) -> dict:
    record = {
        "id": f"evt_{uuid.uuid4().hex[:14]}",
        "seq": next(_seq),
        "event": event,
        "deliveries": [],
        "signature": "0" * 64 if bad_signature else None,
    }
    state.webhooks.append(record)
    if deliver and not state.webhooks_paused:

        async def later() -> None:
            await asyncio.sleep(delay)
            await _deliver(record)

        asyncio.get_running_loop().create_task(later())
    return record


# Linked accounts (Accounts API v2) --------------------------------------------


@app.post("/v2/accounts")
async def create_account(request: Request):
    _check_auth(request)
    body = await request.json()
    if not body.get("email"):
        raise _error(400, "email is required")
    account = {"id": _id("acc"), "status": "created", **body}
    state.accounts[account["id"]] = account
    return account


@app.post("/v2/accounts/{account_id}/stakeholders")
async def create_stakeholder(account_id: str, request: Request):
    _check_auth(request)
    if account_id not in state.accounts:
        raise _error(404, "account not found")
    return {"id": _id("sth"), **(await request.json())}


@app.post("/v2/accounts/{account_id}/products")
async def request_product(account_id: str, request: Request):
    _check_auth(request)
    product = {"id": _id("acc_prd"), "account_id": account_id, "activation_status": "requested"}
    state.products[product["id"]] = product
    return product


@app.patch("/v2/accounts/{account_id}/products/{product_id}")
async def update_product(account_id: str, product_id: str, request: Request):
    _check_auth(request)
    product = state.products.get(product_id)
    if product is None:
        raise _error(404, "product not found")
    body = await request.json()
    if "settlements" in body:
        product["activation_status"] = ACTIVATION_STATUS
    return product


@app.get("/v2/accounts/{account_id}/products/{product_id}")
async def fetch_product(account_id: str, product_id: str, request: Request):
    _check_auth(request)
    product = state.products.get(product_id)
    if product is None:
        raise _error(404, "product not found")
    return product


# Orders and payments -----------------------------------------------------------


@app.post("/v1/orders")
async def create_order(request: Request):
    _check_auth(request)
    body = await request.json()
    if not isinstance(body.get("amount"), int) or body["amount"] < 100:
        raise _error(400, "The amount must be at least INR 1.00")
    for transfer in body.get("transfers", []):
        if transfer.get("amount", 0) > body["amount"]:
            raise _error(400, "Transfer amount exceeds order amount")
    order = {
        "id": _id("order"),
        "entity": "order",
        "amount": body["amount"],
        "amount_paid": 0,
        "currency": body.get("currency", "INR"),
        "receipt": body.get("receipt"),
        "notes": body.get("notes", {}),
        "status": "created",
        "transfers": body.get("transfers", []),
        "created_at": int(time.time()),
    }
    state.orders[order["id"]] = order
    return order


@app.get("/v1/orders/{order_id}/payments")
async def order_payments(order_id: str, request: Request):
    _check_auth(request)
    items = [p for p in state.payments.values() if p["order_id"] == order_id]
    return {"entity": "collection", "count": len(items), "items": items}


def _page(items: list[dict], request: Request) -> dict:
    params = request.query_params
    start, end = int(params.get("from", 0)), int(params.get("to", 2**40))
    items = [i for i in items if start <= i["created_at"] <= end]
    skip, count = int(params.get("skip", 0)), int(params.get("count", 10))
    page = items[skip : skip + count]
    return {"entity": "collection", "count": len(page), "items": page}


@app.get("/v1/payments")
async def list_payments(request: Request):
    _check_auth(request)
    return _page(list(state.payments.values()), request)


@app.get("/v1/payments/{payment_id}")
async def fetch_payment(payment_id: str, request: Request):
    _check_auth(request)
    if payment_id not in state.payments:
        raise _error(404, "payment not found")
    return state.payments[payment_id]


@app.get("/v1/payments/{payment_id}/transfers")
async def payment_transfers(payment_id: str, request: Request):
    _check_auth(request)
    items = [t for t in state.transfers.values() if t["source"] == payment_id]
    return {"entity": "collection", "count": len(items), "items": items}


class RefundIn(BaseModel):
    amount: int | None = None
    reverse_all: int | bool = 0
    notes: dict[str, Any] = {}


@app.post("/v1/payments/{payment_id}/refund")
async def refund(payment_id: str, body: RefundIn, request: Request):
    _check_auth(request)
    payment = state.payments.get(payment_id)
    if payment is None or payment["status"] != "captured":
        raise _error(400, "The payment has not been captured")
    amount = body.amount or payment["amount"] - payment["amount_refunded"]
    if amount > payment["amount"] - payment["amount_refunded"]:
        raise _error(400, "The refund amount exceeds the captured amount")
    payment["amount_refunded"] += amount
    payment["refund_status"] = (
        "full" if payment["amount_refunded"] == payment["amount"] else "partial"
    )
    refund = {
        "id": _id("rfnd"),
        "entity": "refund",
        "payment_id": payment_id,
        "amount": amount,
        "currency": "INR",
        "status": "processed",
        "notes": body.notes,
        "created_at": int(time.time()),
    }
    if body.reverse_all:
        for transfer in state.transfers.values():
            if transfer["source"] == payment_id:
                transfer["amount_reversed"] = transfer.get("amount_reversed", 0) + amount
    state.refunds[refund["id"]] = refund
    _queue(_event("refund.processed", refund=refund, payment=payment))
    return refund


@app.get("/v1/refunds")
async def list_refunds(request: Request):
    _check_auth(request)
    return _page(list(state.refunds.values()), request)


@app.get("/v1/settlements")
async def list_settlements(request: Request):
    """Test mode makes no settlements, so the list is always empty."""
    _check_auth(request)
    return {"entity": "collection", "count": 0, "items": []}


# Simulator controls ------------------------------------------------------------


class PayIn(BaseModel):
    outcome: str = "captured"  # captured or failed
    webhooks: str = "now"  # now, late, none or twice
    delay_seconds: float = 3.0
    amount: int | None = None  # pay a different amount than the order (mismatch tests)


@app.post("/sim/orders/{order_id}/pay")
async def pay(order_id: str, body: PayIn):
    """Act as the payer completing Checkout. Returns what Checkout hands the app."""
    order = state.orders.get(order_id)
    if order is None:
        raise _error(404, "order not found")
    if any(p["status"] == "captured" for p in state.payments.values() if p["order_id"] == order_id):
        raise _error(400, "order already paid")
    payment = {
        "id": _id("pay"),
        "entity": "payment",
        "order_id": order_id,
        "amount": body.amount or order["amount"],
        "currency": "INR",
        "status": "captured" if body.outcome == "captured" else "failed",
        "method": "upi",
        "captured": body.outcome == "captured",
        "amount_refunded": 0,
        "refund_status": None,
        "error_description": None if body.outcome == "captured" else "Payment declined by bank",
        "created_at": int(time.time()),
    }
    state.payments[payment["id"]] = payment
    deliver = body.webhooks != "none"
    delay = body.delay_seconds if body.webhooks == "late" else 0.0
    if payment["status"] == "captured":
        order["status"] = "paid"
        order["amount_paid"] = payment["amount"]
        _queue(_event("payment.captured", payment=payment), delay, deliver)
        for spec in order["transfers"]:
            transfer = {
                "id": _id("trf"),
                "entity": "transfer",
                "source": payment["id"],
                "recipient": spec["account"],
                "amount": spec["amount"],
                "currency": "INR",
                "status": "processed",
                "created_at": int(time.time()),
            }
            state.transfers[transfer["id"]] = transfer
            _queue(_event("transfer.processed", transfer=transfer), delay, deliver)
        if body.webhooks == "twice":
            _queue(_event("payment.captured", payment=payment))
        return {
            "razorpay_payment_id": payment["id"],
            "razorpay_order_id": order_id,
            "razorpay_signature": checkout_signature(order_id, payment["id"]),
        }
    _queue(_event("payment.failed", payment=payment), delay, deliver)
    return {
        "error": {
            "code": "BAD_REQUEST_ERROR",
            "description": "Payment declined by bank",
            "metadata": {"payment_id": payment["id"], "order_id": order_id},
        }
    }


@app.get("/sim/webhooks")
async def webhooks(event: str | None = None):
    return [w for w in state.webhooks if event is None or w["event"]["event"] == event]


@app.post("/sim/webhooks/{event_id}/replay")
async def replay(event_id: str):
    record = next((w for w in state.webhooks if w["id"] == event_id), None)
    if record is None:
        raise _error(404, "no such webhook")
    await _deliver(record)
    return record


class SendIn(BaseModel):
    event: dict
    bad_signature: bool = False


@app.post("/sim/webhooks/send")
async def send(body: SendIn):
    """Deliver an arbitrary event now (signature and ordering tests)."""
    record = _queue(body.event, deliver=False, bad_signature=body.bad_signature)
    await _deliver(record)
    return record


@app.post("/sim/webhooks/pause")
async def pause(paused: bool = True):
    state.webhooks_paused = paused
    return {"paused": paused}


@app.post("/sim/reset")
async def reset():
    global state
    state = State()
    return {"reset": True}


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}
