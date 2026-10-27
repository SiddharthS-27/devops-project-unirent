import asyncio
import logging

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.core.db import get_engine
from app.core.redis import get_redis

router = APIRouter(tags=["health"])
log = logging.getLogger(__name__)

CHECK_TIMEOUT_SECONDS = 2.0


@router.get("/healthz")
async def healthz() -> dict[str, str]:
    """The process is up. Says nothing about its dependencies."""
    return {"status": "ok"}


async def _check_database() -> None:
    async with get_engine().connect() as connection:
        await connection.execute(text("SELECT 1"))


async def _check_redis() -> None:
    await get_redis().ping()


@router.get("/readyz")
async def readyz() -> JSONResponse:
    """Ready to serve: the database and Redis both answer."""
    checks = {"database": _check_database, "redis": _check_redis}
    results: dict[str, str] = {}
    for name, check in checks.items():
        try:
            await asyncio.wait_for(check(), CHECK_TIMEOUT_SECONDS)
            results[name] = "ok"
        except Exception as exc:  # noqa: BLE001 - any failure means not ready
            log.warning("readiness check failed", extra={"check": name, "error": str(exc)})
            results[name] = "unavailable"
    ready = all(v == "ok" for v in results.values())
    return JSONResponse(
        {"status": "ok" if ready else "unavailable", "checks": results},
        status_code=200 if ready else 503,
    )
