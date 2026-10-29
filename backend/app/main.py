import asyncio
from contextlib import asynccontextmanager

import unirent_payments.db
import unirent_security.db
from fastapi import FastAPI
from prometheus_client import make_asgi_app
from unirent_payments.api import internal_router as payments_internal_router
from unirent_payments.idempotency import IdempotencyMiddleware

from app.api import api_router
from app.core.config import get_settings
from app.core.db import dispose_engine, get_sessionmaker
from app.core.errors import register_error_handlers
from app.core.logging import configure_logging
from app.core.metrics import MetricsMiddleware, gauge_loop
from app.core.middleware import RequestContextMiddleware
from app.core.redis import close_redis, get_redis
from app.modules.admin.router import load_clock_offset
from app.modules.health.router import router as health_router
from app.modules.internal.router import router as internal_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        await load_clock_offset()
    except Exception:  # noqa: BLE001 - Redis down at startup: run on real time
        pass
    stop = asyncio.Event()
    gauges = asyncio.create_task(gauge_loop(stop))
    yield
    stop.set()
    await gauges
    await close_redis()
    await dispose_engine()


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.log_level)
    app = FastAPI(title="UniRent API", version="0.1.0", lifespan=lifespan)
    app.add_middleware(IdempotencyMiddleware)
    app.add_middleware(MetricsMiddleware)
    # Added last, so it runs first: every request gets its ID before anything else.
    app.add_middleware(RequestContextMiddleware)
    register_error_handlers(app)
    app.include_router(health_router)
    app.include_router(api_router)
    app.include_router(internal_router)
    app.include_router(payments_internal_router)
    app.mount("/metrics", make_asgi_app())
    # The installed packages share the api's connection pool and Redis client.
    unirent_security.db.setup(get_sessionmaker(), get_redis())
    unirent_payments.db.setup(get_sessionmaker(), get_redis())
    return app


app = create_app()
