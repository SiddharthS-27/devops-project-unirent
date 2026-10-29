import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.modules.listings.schemas import Category, CategoryOut, ListingCard, ListingKind

SortOrder = Literal["trust", "newest", "price_asc", "price_desc"]


class Suggestion(BaseModel):
    listing_id: uuid.UUID
    title: str
    category: Category
    kind: ListingKind


class HomeOut(BaseModel):
    categories: list[CategoryOut]
    recent: list[ListingCard]
    saved_search_matches: list[ListingCard]


class SavedSearchIn(BaseModel):
    name: str | None = Field(None, max_length=100)
    q: str | None = Field(None, max_length=100)
    category: Category | None = None
    kind: ListingKind | None = None
    min_price_paise: int | None = Field(None, ge=0)
    max_price_paise: int | None = Field(None, ge=0)


class SavedSearchOut(SavedSearchIn):
    id: uuid.UUID
    created_at: datetime
    new_match_count: int
