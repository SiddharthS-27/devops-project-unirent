"""An in-process stand-in for the Razorpay API, for unit tests (httpx MockTransport).
The full simulator with signed webhooks lives in tests/razorpay_sim/ at the repo root."""

import json
import uuid

import httpx


def _id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:14]}"


class FakeRazorpay:
    def __init__(self, activation_status: str = "activated"):
        self.activation_status = activation_status
        self.orders: dict[str, dict] = {}
        self.payments: dict[str, dict] = {}
        self.refunds: dict[str, dict] = {}
        self.calls: list[tuple[str, str]] = []
        self.fail_next: int | None = None

    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self.handle)

    def handle(self, request: httpx.Request) -> httpx.Response:
        path, method = request.url.path, request.method
        self.calls.append((method, path))
        if self.fail_next:
            status, self.fail_next = self.fail_next, None
            return httpx.Response(status, json={"error": {"description": "simulated failure"}})
        body = json.loads(request.content) if request.content else {}
        parts = path.strip("/").split("/")

        if parts[:2] == ["v2", "accounts"]:
            if len(parts) == 2:
                return httpx.Response(200, json={"id": _id("acc"), **body})
            if parts[3] == "stakeholders":
                return httpx.Response(200, json={"id": _id("sth")})
            if parts[3] == "products":
                return httpx.Response(
                    200,
                    json={
                        "id": parts[4] if len(parts) > 4 else _id("acc_prd"),
                        "activation_status": self.activation_status,
                    },
                )
        if path == "/v1/orders" and method == "POST":
            order = {"id": _id("order"), "status": "created", **body}
            self.orders[order["id"]] = order
            return httpx.Response(200, json=order)
        if parts[:2] == ["v1", "orders"] and parts[-1] == "payments":
            items = [p for p in self.payments.values() if p["order_id"] == parts[2]]
            return httpx.Response(200, json={"items": items})
        if parts[:2] == ["v1", "payments"] and len(parts) == 4 and parts[3] == "refund":
            refund = {"id": _id("rfnd"), "payment_id": parts[2], "status": "processed", **body}
            self.refunds[refund["id"]] = refund
            return httpx.Response(200, json=refund)
        if parts[:2] == ["v1", "payments"] and len(parts) == 4 and parts[3] == "transfers":
            payment = self.payments[parts[2]]
            return httpx.Response(200, json={"items": payment.get("transfers", [])})
        if parts[:2] == ["v1", "payments"] and len(parts) == 3:
            return httpx.Response(200, json=self.payments[parts[2]])
        if path in ("/v1/payments", "/v1/refunds", "/v1/settlements"):
            source = {
                "/v1/payments": self.payments,
                "/v1/refunds": self.refunds,
                "/v1/settlements": {},
            }[path]
            return httpx.Response(200, json={"items": list(source.values())})
        return httpx.Response(404, json={"error": {"description": f"no route {path}"}})

    def pay(self, order_id: str, status: str = "captured") -> dict:
        """What happens when the user completes Checkout."""
        order = self.orders[order_id]
        payment = {
            "id": _id("pay"),
            "order_id": order_id,
            "amount": order["amount"],
            "currency": "INR",
            "status": status,
            "method": "upi",
            "created_at": 1_800_000_000,
            "transfers": [
                {"id": _id("trf"), "amount": t["amount"], "recipient": t["account"]}
                for t in order.get("transfers", [])
            ],
        }
        self.payments[payment["id"]] = payment
        return payment
