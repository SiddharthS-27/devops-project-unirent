import httpx
import pytest

from app.core.db import dispose_engine
from app.core.redis import close_redis
from app.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    await close_redis()
    await dispose_engine()
