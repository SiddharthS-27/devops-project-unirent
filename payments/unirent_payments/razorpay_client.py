"""A small async client for the Razorpay endpoints UniRent uses.

The base URL is configurable so tests and keyless environments can use the
simulator in tests/razorpay_sim/."""

import logging
from typing import Any

import httpx
from unirent_security.errors import ApiError

from unirent_payments.config import get_settings

log = logging.getLogger(__name__)


class RazorpayError(ApiError):
    def __init__(self, status: int, description: str):
        super().__init__(502, "PAYMENT_PROVIDER_ERROR", f"Razorpay: {description}")
        self.provider_status = status


class RazorpayClient:
    def __init__(self, transport: httpx.AsyncBaseTransport | None = None):
        settings = get_settings()
        self._client = httpx.AsyncClient(
            base_url=settings.razorpay_api_base.rstrip("/"),
            auth=(settings.razorpay_key_id, settings.razorpay_key_secret),
            timeout=settings.razorpay_timeout_seconds,
            transport=transport,
        )

    async def aclose(self) -> None:
        await self._client.aclose()

    async def _call(self, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
        try:
            response = await self._client.request(method, path, **kwargs)
        except httpx.HTTPError as exc:
            log.warning("razorpay unreachable", extra={"path": path, "error": str(exc)})
            raise RazorpayError(0, "unreachable") from exc
        if response.status_code >= 400:
            try:
                description = response.json()["error"]["description"]
            except (ValueError, KeyError, TypeError):
                description = response.text[:200]
            log.warning(
                "razorpay error",
                extra={"path": path, "status": response.status_code, "error": description},
            )
            raise RazorpayError(response.status_code, description)
        return response.json()

    # Route linked accounts (Accounts API v2)
    async def create_account(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._call("POST", "/v2/accounts", json=payload)

    async def create_stakeholder(self, account_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._call("POST", f"/v2/accounts/{account_id}/stakeholders", json=payload)

    async def request_route_product(self, account_id: str) -> dict[str, Any]:
        return await self._call(
            "POST",
            f"/v2/accounts/{account_id}/products",
            json={"product_name": "route", "tnc_accepted": True},
        )

    async def update_product(
        self, account_id: str, product_id: str, payload: dict[str, Any]
    ) -> dict[str, Any]:
        return await self._call(
            "PATCH", f"/v2/accounts/{account_id}/products/{product_id}", json=payload
        )

    async def fetch_product(self, account_id: str, product_id: str) -> dict[str, Any]:
        return await self._call("GET", f"/v2/accounts/{account_id}/products/{product_id}")

    # Orders, payments, transfers, refunds, settlements
    async def create_order(self, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._call("POST", "/v1/orders", json=payload)

    async def order_payments(self, order_id: str) -> list[dict[str, Any]]:
        return (await self._call("GET", f"/v1/orders/{order_id}/payments"))["items"]

    async def fetch_payment(self, payment_id: str) -> dict[str, Any]:
        return await self._call("GET", f"/v1/payments/{payment_id}")

    async def payments_between(self, start: int, end: int) -> list[dict[str, Any]]:
        return await self._paged("/v1/payments", {"from": start, "to": end})

    async def payment_transfers(self, payment_id: str) -> list[dict[str, Any]]:
        return (await self._call("GET", f"/v1/payments/{payment_id}/transfers"))["items"]

    async def refund(self, payment_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        return await self._call("POST", f"/v1/payments/{payment_id}/refund", json=payload)

    async def refunds_between(self, start: int, end: int) -> list[dict[str, Any]]:
        return await self._paged("/v1/refunds", {"from": start, "to": end})

    async def settlements_between(self, start: int, end: int) -> list[dict[str, Any]]:
        return await self._paged("/v1/settlements", {"from": start, "to": end})

    async def _paged(self, path: str, params: dict[str, Any]) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        skip = 0
        while True:
            page = await self._call("GET", path, params={**params, "count": 100, "skip": skip})
            batch = page.get("items", [])
            items.extend(batch)
            if len(batch) < 100:
                return items
            skip += 100


_client: RazorpayClient | None = None


def razorpay() -> RazorpayClient:
    global _client
    if _client is None:
        _client = RazorpayClient()
    return _client


def use_client(client: RazorpayClient | None) -> None:
    """Swap the client (tests)."""
    global _client
    _client = client
