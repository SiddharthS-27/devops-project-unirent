"""Delivery through Firebase Cloud Messaging (HTTP v1), or to the log.

FCM answers each send synchronously, so the receipt check happens inline:
a token FCM no longer knows is removed through the backend."""

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Protocol

import httpx

from unirent_workers.backend_api import BackendApi
from unirent_workers.config import get_settings
from unirent_workers.metrics import PUSH_SENT

log = logging.getLogger(__name__)

FCM_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"
SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
DEAD_TOKEN_ERRORS = {"UNREGISTERED", "INVALID_ARGUMENT", "NOT_FOUND"}


@dataclass(frozen=True)
class Push:
    account_id: str
    title: str
    body: str
    link: str  # unirent://... deep link the app opens
    data: dict[str, str] = field(default_factory=dict)


class Sender(Protocol):
    async def send(self, token: str, push: Push) -> str:
        """Returns 'sent', 'dead_token' or 'failed'."""


class LogSender:
    """Development: write the push to the log and keep it for tests."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, Push]] = []

    async def send(self, token: str, push: Push) -> str:
        self.sent.append((token, push))
        log.info(
            "push",
            extra={"account_id": push.account_id, "title": push.title, "link": push.link},
        )
        return "sent"


class FcmSender:
    def __init__(self, transport: httpx.AsyncBaseTransport | None = None):
        from google.oauth2 import service_account

        settings = get_settings()
        self._credentials = service_account.Credentials.from_service_account_file(
            settings.fcm_credentials_file, scopes=[SCOPE]
        )
        self._url = FCM_URL.format(project=settings.fcm_project_id)
        self._client = httpx.AsyncClient(timeout=10, transport=transport)

    async def _token(self) -> str:
        if not self._credentials.valid:
            from google.auth.transport.requests import Request

            await asyncio.to_thread(self._credentials.refresh, Request())
        return self._credentials.token

    async def send(self, token: str, push: Push) -> str:
        message = {
            "message": {
                "token": token,
                "notification": {"title": push.title, "body": push.body},
                "data": {"link": push.link, **push.data},
                "android": {"priority": "high"},
            }
        }
        response = await self._client.post(
            self._url, json=message, headers={"Authorization": f"Bearer {await self._token()}"}
        )
        if response.status_code == 200:
            return "sent"
        try:
            details = response.json()["error"].get("details", [])
            codes = {d.get("errorCode") for d in details} | {response.json()["error"].get("status")}
        except (ValueError, KeyError, AttributeError):
            codes = set()
        if codes & DEAD_TOKEN_ERRORS:
            return "dead_token"
        log.warning("fcm send failed", extra={"status": response.status_code})
        return "failed"


def make_sender() -> Sender:
    return FcmSender() if get_settings().push_mode == "fcm" else LogSender()


class PushDelivery:
    def __init__(self, backend: BackendApi, sender: Sender):
        self.backend = backend
        self.sender = sender

    async def deliver(self, push: Push) -> int:
        """Send to every device of the account; returns how many succeeded."""
        delivered = 0
        for token in await self.backend.push_tokens(push.account_id):
            outcome = await self.sender.send(token, push)
            PUSH_SENT.labels(outcome=outcome).inc()
            if outcome == "dead_token":
                await self.backend.delete_push_token(token)
            elif outcome == "failed":
                raise RuntimeError("push delivery failed")
            else:
                delivered += 1
        return delivered
