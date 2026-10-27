import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class DeviceToken(Base):
    """A push token (FCM) for one device. A token moves with whoever signed in last."""

    __tablename__ = "device_tokens"

    token: Mapped[str] = mapped_column(String(500), primary_key=True)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID, index=True)
    platform: Mapped[str] = mapped_column(String(10))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
