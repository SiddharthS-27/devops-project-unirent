"""Support threads: the help bot hands a conversation to the moderators, who
answer in the same thread."""

import uuid
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import AccountContext, audit

from app.core.clock import now
from app.core.errors import ApiError, not_found
from app.core.outbox import emit
from app.modules.help.models import SupportMessage, SupportThread
from app.modules.help.schemas import (
    HandoffIn,
    SupportThreadOut,
    SupportThreadSummary,
)
from app.modules.help.schemas import (
    SupportMessage as SupportMessageOut,
)
from app.modules.profiles.service import profiles_for

SUBJECT_LENGTH = 80


async def handoff(session: AsyncSession, account: AccountContext, body: HandoffIn) -> SupportThread:
    at = now()
    thread = SupportThread(
        id=uuid.uuid4(),
        account_id=account.id,
        booking_id=body.booking_id,
        subject=body.message[:SUBJECT_LENGTH],
        status="open",
        unanswered=True,
        created_at=at,
        updated_at=at,
    )
    session.add(thread)
    await session.flush()
    # Keep the conversation's order: one microsecond apart.
    for n, line in enumerate(body.transcript):
        session.add(
            SupportMessage(
                id=uuid.uuid4(),
                thread_id=thread.id,
                author=line.author,
                author_id=account.id if line.author == "user" else None,
                body=line.text,
                at=at + timedelta(microseconds=n),
            )
        )
    session.add(
        SupportMessage(
            id=uuid.uuid4(),
            thread_id=thread.id,
            author="user",
            author_id=account.id,
            body=body.message,
            at=at + timedelta(microseconds=len(body.transcript)),
        )
    )
    return thread


async def get_thread(
    session: AsyncSession, thread_id: uuid.UUID, viewer: AccountContext, *, lock=False
) -> SupportThread:
    thread = await session.get(SupportThread, thread_id, with_for_update=lock)
    if thread is None or (thread.account_id != viewer.id and not viewer.is_staff):
        raise not_found("Thread")
    return thread


async def post(
    session: AsyncSession, thread_id: uuid.UUID, author: AccountContext, text: str
) -> SupportMessage:
    thread = await get_thread(session, thread_id, author, lock=True)
    if thread.status == "closed":
        raise ApiError(409, "THREAD_CLOSED", "This conversation is closed; start a new one")
    staff_reply = author.is_staff
    message = SupportMessage(
        id=uuid.uuid4(),
        thread_id=thread.id,
        author="moderator" if staff_reply else "user",
        author_id=author.id,
        body=text,
        at=now(),
    )
    session.add(message)
    thread.updated_at = now()
    thread.unanswered = not staff_reply
    if staff_reply:
        emit(
            session,
            "SupportReplyPosted",
            thread.id,
            {
                "thread_id": str(thread.id),
                "account_id": str(thread.account_id),
                "preview": text[:120],
            },
        )
        await audit.record(
            author, "support.reply", audit.target("support_thread", thread.id), session=session
        )
    return message


async def close(
    session: AsyncSession, thread_id: uuid.UUID, staff: AccountContext
) -> SupportThread:
    thread = await get_thread(session, thread_id, staff, lock=True)
    thread.status = "closed"
    thread.updated_at = now()
    await audit.record(
        staff, "support.close", audit.target("support_thread", thread.id), session=session
    )
    return thread


async def thread_out(session: AsyncSession, thread: SupportThread) -> SupportThreadOut:
    messages = list(
        await session.scalars(
            select(SupportMessage)
            .where(SupportMessage.thread_id == thread.id)
            .order_by(SupportMessage.at, SupportMessage.id)
        )
    )
    names = await profiles_for(session, [m.author_id for m in messages if m.author == "user"])
    return SupportThreadOut(
        id=thread.id,
        status=thread.status,  # type: ignore[arg-type]
        subject=thread.subject,
        account_id=thread.account_id,
        booking_id=thread.booking_id,
        messages=[message_out(m, names) for m in messages],
        created_at=thread.created_at,
        updated_at=thread.updated_at,
    )


def message_out(message: SupportMessage, names: dict | None = None) -> SupportMessageOut:
    names = names or {}
    if message.author == "moderator":
        name = "Moderator"
    elif message.author == "bot":
        name = "UniRent help"
    else:
        profile = names.get(message.author_id)
        name = profile.full_name if profile else None
    return SupportMessageOut(
        id=message.id,
        author=message.author,
        author_name=name,
        body=message.body,
        at=message.at,  # type: ignore[arg-type]
    )


async def summaries(
    session: AsyncSession, *, account_id: uuid.UUID | None = None, status: str | None = None
) -> list[SupportThreadSummary]:
    last = (
        select(SupportMessage.thread_id, func.max(SupportMessage.at).label("last"))
        .group_by(SupportMessage.thread_id)
        .subquery()
    )
    stmt = select(SupportThread, last.c.last).join(last, last.c.thread_id == SupportThread.id)
    if account_id:
        stmt = stmt.where(SupportThread.account_id == account_id)
    if status:
        stmt = stmt.where(SupportThread.status == status)
    rows = (await session.execute(stmt.order_by(last.c.last.desc()).limit(200))).all()
    names = await profiles_for(session, [t.account_id for t, _ in rows])
    return [
        SupportThreadSummary(
            id=t.id,
            status=t.status,  # type: ignore[arg-type]
            subject=t.subject,
            account_id=t.account_id,
            account_name=names[t.account_id].full_name if t.account_id in names else None,
            booking_id=t.booking_id,
            last_message_at=last_at,
            unanswered=t.unanswered,
        )
        for t, last_at in rows
    ]
