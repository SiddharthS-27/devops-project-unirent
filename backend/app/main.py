from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.db import dispose_engine
from app.core.redis import close_redis


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield
    await close_redis()
    await dispose_engine()


def create_app() -> FastAPI:
    return FastAPI(title="UniRent API", version="0.1.0", lifespan=lifespan)


app = create_app()
