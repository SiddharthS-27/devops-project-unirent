from contextlib import asynccontextmanager

import unirent_security.db
from fastapi import FastAPI

from app.api import api_router
from app.core.config import get_settings
from app.core.db import dispose_engine, get_sessionmaker
from app.core.errors import register_error_handlers
from app.core.logging import configure_logging
from app.core.middleware import RequestContextMiddleware
from app.core.redis import close_redis, get_redis
from app.modules.health.router import router as health_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield
    await close_redis()
    await dispose_engine()


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.log_level)
    app = FastAPI(title="UniRent API", version="0.1.0", lifespan=lifespan)
    app.add_middleware(RequestContextMiddleware)
    register_error_handlers(app)
    app.include_router(health_router)
    app.include_router(api_router)
    # The security package shares the api's connection pool and Redis client.
    unirent_security.db.setup(get_sessionmaker(), get_redis())
    return app


app = create_app()
