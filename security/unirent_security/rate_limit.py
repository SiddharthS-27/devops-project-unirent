"""Redis sliding-window rate limits.

Each limit keeps a sorted set of request times per subject (an IP, an account,
a handover code). The check and the insert run in one Lua script, so parallel
clients can't slip past the limit together."""

import logging
import time
import uuid
from dataclasses import dataclass

from fastapi import Request
from redis.exceptions import RedisError

from unirent_security import db
from unirent_security.errors import ApiError
from unirent_security.metrics import RATE_LIMITED
from unirent_security.roles import AccountContext

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class Limit:
    requests: int
    window_seconds: int
    # Refuse when Redis is down instead of letting requests through.
    fail_closed: bool = False


LIMITS: dict[str, Limit] = {
    "student_signin": Limit(10, 60),  # per IP
    "staff_login": Limit(5, 15 * 60, fail_closed=True),  # per account email
    "otp_entry": Limit(5, 15 * 60, fail_closed=True),  # per handover code
    "payment_start": Limit(10, 60),  # per user
    "chatbot": Limit(20, 60),  # per user
    "default": Limit(120, 60),  # per user
}

_SCRIPT = """
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
if redis.call('ZCARD', key) >= limit then
  local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
  return {0, tonumber(oldest[2])}
end
redis.call('ZADD', key, now, ARGV[4])
redis.call('PEXPIRE', key, window)
return {1, 0}
"""


async def hit(name: str, subject: str) -> None:
    """Count one request for `subject` under limit `name`; 429 when over it."""
    limit = LIMITS[name]
    window_ms = limit.window_seconds * 1000
    now_ms = int(time.time() * 1000)
    try:
        allowed, oldest = await db.redis().eval(
            _SCRIPT,
            1,
            f"rl:{name}:{subject}",
            now_ms,
            window_ms,
            limit.requests,
            f"{now_ms}:{uuid.uuid4().hex}",
        )
    except (OSError, RedisError) as exc:
        log.warning("rate limiter unavailable", extra={"limit": name, "error": str(exc)})
        if limit.fail_closed:
            raise ApiError(503, "TRY_LATER", "Please try again shortly") from None
        return
    if not allowed:
        RATE_LIMITED.labels(route=name).inc()
        retry_after = max(1, (int(oldest) + window_ms - now_ms + 999) // 1000)
        raise ApiError(
            429,
            "RATE_LIMITED",
            "Too many requests. Slow down and try again",
            headers={"Retry-After": str(retry_after)},
        )


def client_ip(request: Request) -> str:
    """The peer address. Uvicorn rewrites it from X-Forwarded-For only for trusted
    proxies (--forwarded-allow-ips), so clients can't spoof it with a header."""
    return request.client.host if request.client else "unknown"


def rate_limit(name: str, by: str = "account"):
    """Dependency enforcing limit `name`, keyed by the signed-in account or the IP."""
    if name not in LIMITS:
        raise ValueError(name)

    async def dependency(request: Request) -> None:
        account: AccountContext | None = getattr(request.state, "account", None)
        if by == "account" and account is not None:
            subject = f"acct:{account.id}"
        else:
            subject = f"ip:{client_ip(request)}"
        await hit(name, subject)

    return dependency
