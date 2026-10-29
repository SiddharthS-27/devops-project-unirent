import uuid

from fastapi import APIRouter
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.core.errors import not_implemented
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
    raise not_implemented()


@router.post("/help/chat", response_model=ChatReply)
async def chat(body: ChatIn, account: CurrentAccount, session: SessionDep):
    """The help bot answers only general questions about how UniRent works."""
    raise not_implemented()


@router.post("/help/handoff", response_model=SupportThreadOut, status_code=201)
async def handoff(body: HandoffIn, account: CurrentAccount, session: SessionDep):
    """Talk to a moderator: opens a support thread holding the chat transcript."""
    raise not_implemented()


@router.get("/support/threads", response_model=list[SupportThreadSummary])
async def my_threads(account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.get("/support/threads/{thread_id}", response_model=SupportThreadOut)
async def my_thread(thread_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.post(
    "/support/threads/{thread_id}/messages", response_model=SupportMessage, status_code=201
)
async def post_message(
    thread_id: uuid.UUID, body: SupportMessageIn, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()
