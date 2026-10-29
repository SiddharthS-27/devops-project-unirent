import uuid
from datetime import datetime

from sqlalchemy import DateTime, SmallInteger, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Profile(Base):
    """A student's profile. The account itself (email, phone, role, status) lives
    in the security schema and is read through unirent_security."""

    __tablename__ = "profiles"

    account_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True)
    full_name: Mapped[str] = mapped_column(String(200))
    photo_key: Mapped[str | None] = mapped_column(String(300))
    roll_number: Mapped[str] = mapped_column(String(50))
    department: Mapped[str] = mapped_column(String(100))
    year: Mapped[int] = mapped_column(SmallInteger)
    residence_type: Mapped[str] = mapped_column(String(20))  # hostel or day_scholar
    hostel_name: Mapped[str | None] = mapped_column(String(100))
    room_number: Mapped[str | None] = mapped_column(String(20))
    home_address: Mapped[str | None] = mapped_column(Text)
    terms_version: Mapped[str | None] = mapped_column(String(20))
    terms_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
