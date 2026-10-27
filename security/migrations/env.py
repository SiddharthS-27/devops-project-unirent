import asyncio

from alembic import context
from sqlalchemy import pool, text
from sqlalchemy.ext.asyncio import create_async_engine

from unirent_security import models  # noqa: F401
from unirent_security.config import get_settings
from unirent_security.db import Base

SCHEMA = "security"


def _url() -> str:
    settings = get_settings()
    return settings.migration_database_url or settings.database_url


def _include_object(obj, name, type_, reflected, compare_to):
    if type_ == "table":
        return obj.schema == SCHEMA
    return True


def _run(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=Base.metadata,
        version_table_schema=SCHEMA,
        include_schemas=True,
        include_object=_include_object,
    )
    with context.begin_transaction():
        context.run_migrations()


async def _run_online() -> None:
    engine = create_async_engine(_url(), poolclass=pool.NullPool)
    async with engine.connect() as connection:
        await connection.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}"))
        await connection.commit()
        await connection.run_sync(_run)
    await engine.dispose()


asyncio.run(_run_online())
