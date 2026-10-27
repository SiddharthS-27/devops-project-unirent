"""The append-only audit log: every sign-in, staff action, ruling and payment action."""

import logging
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from unirent_security import db
from unirent_security.models import AuditEntry
from unirent_security.roles import AccountContext

log = logging.getLogger(__name__)

Actor = AccountContext | uuid.UUID | None


def _actor(actor: Actor) -> tuple[uuid.UUID | None, str | None]:
    if isinstance(actor, AccountContext):
        return actor.id, actor.role
    return actor, None


async def record(
    actor: Actor,
    action: str,
    target: str | None = None,
    details: dict[str, Any] | None = None,
    session: AsyncSession | None = None,
    ip: str | None = None,
) -> None:
    """Write one entry. Pass `session` to commit it with the change it describes;
    without one, the entry is written in its own transaction. `actor` None is the system."""
    actor_id, actor_role = _actor(actor)
    entry = AuditEntry(
        actor_id=actor_id,
        actor_role=actor_role,
        action=action,
        target=target,
        details=details or {},
        ip=ip if ip and ip != "unknown" else None,
    )
    if session is not None:
        session.add(entry)
        return
    async with db.sessionmaker()() as own_session:
        own_session.add(entry)
        await own_session.commit()


async def entries(
    *,
    actor_id: uuid.UUID | None = None,
    target: str | None = None,
    action: str | None = None,
    before_id: int | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """Newest first, for the admin's read-only audit screen. Cursor is the last id seen."""
    stmt = select(AuditEntry).order_by(AuditEntry.id.desc()).limit(min(limit, 200))
    if actor_id:
        stmt = stmt.where(AuditEntry.actor_id == actor_id)
    if target:
        stmt = stmt.where(AuditEntry.target == target)
    if action:
        stmt = stmt.where(AuditEntry.action == action)
    if before_id:
        stmt = stmt.where(AuditEntry.id < before_id)
    async with db.sessionmaker()() as session:
        rows = await session.scalars(stmt)
        return [
            {
                "id": e.id,
                "at": e.at,
                "actor_id": e.actor_id,
                "actor_role": e.actor_role,
                "action": e.action,
                "target": e.target,
                "details": e.details,
            }
            for e in rows
        ]


def target(kind: str, ref: uuid.UUID | str) -> str:
    return f"{kind}:{ref}"
