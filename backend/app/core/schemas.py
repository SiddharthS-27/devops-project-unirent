"""Shapes shared by many modules."""

from datetime import datetime

from pydantic import BaseModel, Field


class Page[T](BaseModel):
    """Cursor pagination: pass next_cursor back as ?cursor= until it is null."""

    items: list[T]
    next_cursor: str | None = None


class PhotoOut(BaseModel):
    id: str
    url: str


class ServerTime(BaseModel):
    now: datetime = Field(description="Server time (UTC). The app derives its clock offset")
