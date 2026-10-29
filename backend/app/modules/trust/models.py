import uuid
from datetime import datetime

from sqlalchemy import DateTime, Integer, Numeric, SmallInteger, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class TrustScore(Base):
    """Each student's two trust scores and the counts behind them. Scores stay
    null until 5 completed trades, when the New badge goes away."""

    __tablename__ = "trust_scores"

    account_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True)
    lender_score: Mapped[int | None] = mapped_column(SmallInteger)
    renter_score: Mapped[int | None] = mapped_column(SmallInteger)
    lender_rating: Mapped[float | None] = mapped_column(Numeric(3, 2))
    renter_rating: Mapped[float | None] = mapped_column(Numeric(3, 2))
    lender_reviews: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    renter_reviews: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    completed_trades: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    cancellations: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
