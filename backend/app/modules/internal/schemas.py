import uuid
from datetime import datetime

from pydantic import BaseModel


class DueTimer(BaseModel):
    id: uuid.UUID
    kind: str
    ref_id: uuid.UUID
    due_at: datetime


class DueTimers(BaseModel):
    timers: list[DueTimer]


class FireResult(BaseModel):
    fired: bool
    outcome: str


class SavedSearchMatch(BaseModel):
    saved_search_id: uuid.UUID
    account_id: uuid.UUID
    name: str | None


class SavedSearchMatches(BaseModel):
    listing_id: uuid.UUID
    title: str
    matches: list[SavedSearchMatch]
