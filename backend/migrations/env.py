import asyncio

from alembic import context
from sqlalchemy import pool, text
from sqlalchemy.ext.asyncio import create_async_engine

import app.modules  # noqa: F401  (imports every model module)
from app.core.config import get_settings
from app.core.db import Base

target_metadata = Base.metadata
SCHEMA = "core"


def _url() -> str:
    settings = get_settings()
    return settings.migration_database_url or settings.database_url


def _include_object(obj, name, type_, reflected, compare_to):
    # Only the core schema belongs to this migration history.
    if type_ == "table":
        return obj.schema == SCHEMA
    return True


def _run(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
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


if context.is_offline_mode():
    context.configure(url=_url(), target_metadata=target_metadata, version_table_schema=SCHEMA)
    with context.begin_transaction():
        context.run_migrations()
else:
    asyncio.run(_run_online())
