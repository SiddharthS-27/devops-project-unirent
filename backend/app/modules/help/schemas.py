import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class FaqOut(BaseModel):
    id: uuid.UUID
    question: str
    answer: str
    topic: str


class ChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=500)


class ChatReply(BaseModel):
    """Either an answer from the FAQs, or a fallback offering the FAQs and a moderator."""

    kind: Literal["answer", "fallback"]
    text: str
    faq_id: uuid.UUID | None = None
    actions: list[Literal["see_faqs", "talk_to_moderator"]] = []


class TranscriptLine(BaseModel):
    author: Literal["user", "bot"]
    text: str = Field(max_length=1000)


class HandoffIn(BaseModel):
    message: str = Field(min_length=1, max_length=1000, description="What the user needs")
    transcript: list[TranscriptLine] = Field([], max_length=50)
    booking_id: uuid.UUID | None = None


class SupportMessageIn(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class SupportMessage(BaseModel):
    id: uuid.UUID
    author: Literal["user", "bot", "moderator"]
    author_name: str | None
    body: str
    at: datetime


class SupportThreadOut(BaseModel):
    id: uuid.UUID
    status: Literal["open", "closed"]
    subject: str
    account_id: uuid.UUID
    booking_id: uuid.UUID | None
    messages: list[SupportMessage]
    created_at: datetime
    updated_at: datetime


class SupportThreadSummary(BaseModel):
    id: uuid.UUID
    status: Literal["open", "closed"]
    subject: str
    account_id: uuid.UUID
    account_name: str | None
    booking_id: uuid.UUID | None
    last_message_at: datetime
    unanswered: bool
