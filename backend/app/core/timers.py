"""Timer writer. Every time-based rule is a row here; see app.core.models.Timer."""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.clock import now
from app.core.models import Timer


def schedule(
    session: AsyncSession,
    kind: str,
    ref_id: uuid.UUID,
    due_at: datetime,
    payload: dict[str, Any] | None = None,
) -> Timer:
    timer = Timer(
        id=uuid.uuid4(),
        kind=kind,
        ref_id=ref_id,
        due_at=due_at,
        payload=payload or {},
        created_at=now(),
    )
    session.add(timer)
    return timer


async def cancel_timers(
    session: AsyncSession, ref_id: uuid.UUID, kind: str | list[str] | None = None
) -> None:
    """Cancel pending timers for a reference, optionally only of some kinds."""
    stmt = (
        update(Timer)
        .where(Timer.ref_id == ref_id, Timer.fired_at.is_(None), Timer.cancelled_at.is_(None))
        .values(cancelled_at=now())
    )
    if isinstance(kind, str):
        stmt = stmt.where(Timer.kind == kind)
    elif kind:
        stmt = stmt.where(Timer.kind.in_(kind))
    await session.execute(stmt)
