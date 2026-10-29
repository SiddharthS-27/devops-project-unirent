import pytest
from sqlalchemy import text

from unirent_workers import db


@pytest.fixture
async def session():
    """A database session, or a skip when PostgreSQL isn't reachable or migrated."""
    try:
        async with db.sessionmaker()() as s:
            await s.execute(text("SELECT 1 FROM core.outbox LIMIT 1"))
            yield s
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"database unavailable: {exc}")


class FakeProducer:
    def __init__(self, fail_on: int | None = None):
        self.sent: list[tuple[str, dict, bytes]] = []
        self.fail_on = fail_on

    async def send_and_wait(self, topic, value, key):
        import json

        if self.fail_on is not None and len(self.sent) == self.fail_on:
            raise ConnectionError("broker down")
        self.sent.append((topic, json.loads(value), key))
