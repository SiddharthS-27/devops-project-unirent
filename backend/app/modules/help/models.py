import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class SupportThread(Base):
    """A conversation handed from the help bot to the moderators."""

    __tablename__ = "support_threads"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    booking_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    subject: Mapped[str] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(String(10))  # open or closed
    unanswered: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class SupportMessage(Base):
    __tablename__ = "support_messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    thread_id: Mapped[uuid.UUID] = mapped_column(
        UUID, ForeignKey("core.support_threads.id", ondelete="CASCADE"), index=True
    )
    author: Mapped[str] = mapped_column(String(10))  # user, bot or moderator
    author_id: Mapped[uuid.UUID | None] = mapped_column(UUID)
    body: Mapped[str] = mapped_column(Text)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
