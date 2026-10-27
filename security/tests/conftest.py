import pytest
from sqlalchemy import text

from unirent_security import db


@pytest.fixture
async def session():
    """A database session, or a skip when PostgreSQL isn't reachable."""
    try:
        async with db.sessionmaker()() as s:
            await s.execute(text("SELECT 1 FROM security.accounts LIMIT 1"))
            yield s
    except OSError as exc:
        pytest.skip(f"database unavailable: {exc}")
