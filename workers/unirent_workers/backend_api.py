"""The backend's internal routes, called with the service token."""

import uuid
from typing import Any

import httpx

from unirent_workers.config import get_settings


class BackendApi:
    def __init__(self, transport: httpx.AsyncBaseTransport | None = None):
        settings = get_settings()
        self._client = httpx.AsyncClient(
            base_url=settings.api_base_url.rstrip("/"),
            headers={"X-Service-Token": settings.service_token},
            timeout=60,  # reconciliation pulls a day of Razorpay records
            transport=transport,
        )

    async def aclose(self) -> None:
        await self._client.aclose()

    async def _json(self, method: str, path: str, **kwargs: Any) -> Any:
        response = await self._client.request(method, path, **kwargs)
        response.raise_for_status()
        return response.json() if response.content else None

    async def push_tokens(self, account_id: uuid.UUID | str) -> list[str]:
        return (await self._json("GET", f"/internal/accounts/{account_id}/push-tokens"))["tokens"]

    async def delete_push_token(self, token: str) -> None:
        await self._json("DELETE", f"/internal/push-tokens/{token}")

    async def due_timers(self, limit: int = 100) -> list[dict]:
        return (await self._json("GET", "/internal/timers/due", params={"limit": limit}))["timers"]

    async def fire_timer(self, timer_id: str) -> dict:
        return await self._json("POST", f"/internal/timers/{timer_id}/fire")

    async def saved_search_matches(self, listing_id: str) -> dict:
        return await self._json(
            "GET", "/internal/saved-searches/matches", params={"listing_id": listing_id}
        )

    async def run_reconciliation(self) -> dict:
        return await self._json("POST", "/internal/reconciliation/run", json={})
