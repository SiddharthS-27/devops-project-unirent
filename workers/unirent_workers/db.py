from sqlalchemy import MetaData
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from unirent_workers.config import get_settings


class Base(DeclarativeBase):
    metadata = MetaData(schema="workers")


_sessionmaker: async_sessionmaker[AsyncSession] | None = None


def sessionmaker() -> async_sessionmaker[AsyncSession]:
    global _sessionmaker
    if _sessionmaker is None:
        engine = create_async_engine(
            get_settings().workers_database_url, pool_size=5, pool_pre_ping=True
        )
        _sessionmaker = async_sessionmaker(engine, expire_on_commit=False)
    return _sessionmaker


async def dispose() -> None:
    global _sessionmaker
    if _sessionmaker is not None:
        await _sessionmaker.kw["bind"].dispose()
    _sessionmaker = None
