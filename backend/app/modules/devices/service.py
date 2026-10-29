import uuid

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.clock import now
from app.modules.devices.models import DeviceToken


async def register(session: AsyncSession, account_id: uuid.UUID, token: str, platform: str) -> None:
    stmt = insert(DeviceToken).values(
        token=token, account_id=account_id, platform=platform, last_seen_at=now()
    )
    await session.execute(
        stmt.on_conflict_do_update(
            index_elements=[DeviceToken.token],
            set_={"account_id": account_id, "platform": platform, "last_seen_at": now()},
        )
    )


async def remove(session: AsyncSession, token: str, account_id: uuid.UUID | None = None) -> None:
    stmt = delete(DeviceToken).where(DeviceToken.token == token)
    if account_id is not None:
        stmt = stmt.where(DeviceToken.account_id == account_id)
    await session.execute(stmt)


async def tokens_for(session: AsyncSession, account_id: uuid.UUID) -> list[str]:
    rows = await session.scalars(
        select(DeviceToken.token).where(DeviceToken.account_id == account_id)
    )
    return list(rows)
