import uuid

from fastapi import APIRouter, Depends
from unirent_security import CurrentAccount, rate_limit

from app.core.deps import SessionDep
from app.modules.help import chatbot, support
from app.modules.help.schemas import (
    ChatIn,
    ChatReply,
    FaqOut,
    HandoffIn,
    SupportMessage,
    SupportMessageIn,
    SupportThreadOut,
    SupportThreadSummary,
)

router = APIRouter(tags=["help"])


@router.get("/help/faqs", response_model=list[FaqOut])
async def faqs(account: CurrentAccount, session: SessionDep):
    return await chatbot.faqs(session)


@router.post("/help/chat", response_model=ChatReply, dependencies=[Depends(rate_limit("chatbot"))])
async def chat(body: ChatIn, account: CurrentAccount, session: SessionDep):
    """The help bot answers only general questions about how UniRent works."""
    return await chatbot.answer(session, body.message)


@router.post("/help/handoff", response_model=SupportThreadOut, status_code=201)
async def handoff(body: HandoffIn, account: CurrentAccount, session: SessionDep):
    """Talk to a moderator: opens a support thread holding the chat transcript."""
    thread = await support.handoff(session, account, body)
    await session.commit()
    return await support.thread_out(session, thread)


@router.get("/support/threads", response_model=list[SupportThreadSummary])
async def my_threads(account: CurrentAccount, session: SessionDep):
    return await support.summaries(session, account_id=account.id)


@router.get("/support/threads/{thread_id}", response_model=SupportThreadOut)
async def my_thread(thread_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    return await support.thread_out(session, await support.get_thread(session, thread_id, account))


@router.post(
    "/support/threads/{thread_id}/messages", response_model=SupportMessage, status_code=201
)
async def post_message(
    thread_id: uuid.UUID, body: SupportMessageIn, account: CurrentAccount, session: SessionDep
):
    message = await support.post(session, thread_id, account, body.body)
    await session.commit()
    return support.message_out(message)
