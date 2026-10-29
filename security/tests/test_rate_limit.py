import asyncio
import uuid

import pytest

from unirent_security import db
from unirent_security.errors import ApiError
from unirent_security.rate_limit import LIMITS, Limit, hit


@pytest.fixture(autouse=True)
async def redis_or_skip(monkeypatch):
    try:
        await db.redis().ping()
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"redis unavailable: {exc}")
    monkeypatch.setitem(LIMITS, "test", Limit(3, 60))
    yield
    await db.reset()


async def test_allows_up_to_the_limit_then_refuses():
    subject = uuid.uuid4().hex
    for _ in range(3):
        await hit("test", subject)
    with pytest.raises(ApiError) as err:
        await hit("test", subject)
    assert err.value.status_code == 429
    assert int(err.value.headers["Retry-After"]) >= 1


async def test_subjects_are_counted_separately():
    a, b = uuid.uuid4().hex, uuid.uuid4().hex
    for _ in range(3):
        await hit("test", a)
    await hit("test", b)


async def test_parallel_requests_cannot_exceed_the_limit():
    subject = uuid.uuid4().hex
    results = await asyncio.gather(
        *(hit("test", subject) for _ in range(20)), return_exceptions=True
    )
    allowed = [r for r in results if r is None]
    assert len(allowed) == 3


def test_configured_limits_match_the_plan():
    assert LIMITS["student_signin"].requests == 10
    assert LIMITS["staff_login"] == Limit(5, 900, fail_closed=True)
    assert LIMITS["otp_entry"].requests == 5
    assert LIMITS["payment_start"].requests == 10
    assert LIMITS["chatbot"].requests == 20
    assert LIMITS["default"].requests == 120
