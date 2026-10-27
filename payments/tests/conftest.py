import pytest
from sqlalchemy import text

from unirent_payments import db


@pytest.fixture
async def session():
    """A database session, or a skip when PostgreSQL isn't reachable or migrated."""
    try:
        async with db.sessionmaker()() as s:
            await s.execute(text("SELECT 1 FROM payments.outbox LIMIT 1"))
            yield s
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"database unavailable: {exc}")
