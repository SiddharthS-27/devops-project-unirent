import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class SavedSearch(Base):
    """A query and filters a student wants a push for when a new listing matches."""

    __tablename__ = "saved_searches"

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    name: Mapped[str | None] = mapped_column(String(100))
    q: Mapped[str | None] = mapped_column(String(100))
    # The prefix tsquery built from q when it was saved, so matching runs in SQL.
    tsquery: Mapped[str | None] = mapped_column(String(400))
    category: Mapped[str | None] = mapped_column(String(20))
    kind: Mapped[str | None] = mapped_column(String(10))
    min_price_paise: Mapped[int | None] = mapped_column(BigInteger)
    max_price_paise: Mapped[int | None] = mapped_column(BigInteger)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_viewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
