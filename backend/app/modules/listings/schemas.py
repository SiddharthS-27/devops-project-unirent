import uuid
from datetime import date, datetime
from typing import Literal, Self

from pydantic import BaseModel, Field, model_validator

from app.core.schemas import PhotoOut

Category = Literal[
    "electronics",
    "cameras",
    "cycles",
    "books",
    "instruments",
    "sports",
    "hostel",
    "events",
    "other",
]
CATEGORY_LABELS: dict[str, str] = {
    "electronics": "Electronics",
    "cameras": "Cameras and photography",
    "cycles": "Cycles and mobility",
    "books": "Books and study material",
    "instruments": "Musical instruments",
    "sports": "Sports and fitness",
    "hostel": "Hostel essentials",
    "events": "Event and party gear",
    "other": "Other",
}
Condition = Literal["new", "like_new", "good", "fair", "poor"]
ListingKind = Literal["rent", "sale"]
ListingStatus = Literal["active", "paused", "sold", "removed"]
UploadPurpose = Literal["profile", "listing", "handover", "appeal"]


class CategoryOut(BaseModel):
    key: Category
    label: str


class UploadRequest(BaseModel):
    purpose: UploadPurpose
    content_type: Literal["image/jpeg", "image/png", "image/webp"] = "image/jpeg"


class UploadOut(BaseModel):
    """PUT the image bytes to upload_url with these headers, then confirm the
    object_key with the endpoint for what the photo belongs to."""

    object_key: str
    upload_url: str
    method: Literal["PUT"] = "PUT"
    headers: dict[str, str]
    expires_at: datetime


class _Pricing(BaseModel):
    price_per_hour_paise: int | None = Field(None, gt=0)
    price_per_day_paise: int | None = Field(None, gt=0)
    sale_price_paise: int | None = Field(None, gt=0)


class ListingCreate(_Pricing):
    kind: ListingKind
    title: str = Field(min_length=3, max_length=120)
    description: str = Field("", max_length=2000)
    category: Category
    condition: Condition
    manufacture_date: date | None = None
    serial_number: str | None = Field(None, max_length=100)
    pickup_point: str = Field(min_length=2, max_length=200)
    photo_keys: list[str] = Field(min_length=1, max_length=8)
    asset_id: uuid.UUID | None = Field(
        None, description="Relist an item you already own (for example one you bought)"
    )

    @model_validator(mode="after")
    def price_matches_kind(self) -> Self:
        if self.kind == "rent":
            if not (self.price_per_hour_paise or self.price_per_day_paise):
                raise ValueError("rent listings need an hourly or daily price")
            self.sale_price_paise = None
        else:
            if not self.sale_price_paise:
                raise ValueError("sale listings need a price")
            self.price_per_hour_paise = self.price_per_day_paise = None
        return self


class ListingUpdate(_Pricing):
    """Any field; refused while a booking is approved or active."""

    title: str | None = Field(None, min_length=3, max_length=120)
    description: str | None = Field(None, max_length=2000)
    category: Category | None = None
    condition: Condition | None = None
    manufacture_date: date | None = None
    serial_number: str | None = Field(None, max_length=100)
    pickup_point: str | None = Field(None, min_length=2, max_length=200)


class PhotoAdd(BaseModel):
    object_key: str


class OwnerSummary(BaseModel):
    account_id: uuid.UUID
    full_name: str
    photo_url: str | None
    lender_trust: int | None = Field(description="Null while the owner is New")
    is_new: bool


class OwnerCard(OwnerSummary):
    lender_rating: float | None
    cancellation_count: int
    phone: str | None = Field(description="For the Call button")


class ListingCard(BaseModel):
    id: uuid.UUID
    kind: ListingKind
    status: ListingStatus
    title: str
    category: Category
    price_per_hour_paise: int | None
    price_per_day_paise: int | None
    sale_price_paise: int | None
    photo_url: str | None
    pickup_point: str
    owner: OwnerSummary
    created_at: datetime


class AssetHistoryEntry(BaseModel):
    at: datetime
    kind: Literal["listed", "rented", "returned", "sold", "damage_charge"]
    summary: str
    amount_paise: int | None = None
    photos: list[PhotoOut] = []


class AssetOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str = Field(description="From the item's latest listing")
    category: Category
    description: str
    photo_url: str | None = Field(description="Cover photo of the latest listing")
    listing_id: uuid.UUID | None = Field(
        description="The current owner's latest listing of the item, if they listed it"
    )
    listing_status: ListingStatus | None
    condition: Condition
    manufacture_date: date | None
    serial_number: str | None = Field(
        description="Masked to the last 4 characters except for the owner and staff"
    )
    rental_count: int
    history: list[AssetHistoryEntry]


class LateFeeRuleOut(BaseModel):
    id: uuid.UUID
    grace_minutes: int
    base_fee_paise: int
    hourly_percent_bp: int = Field(description="Basis points of the rent per hour: 200 = 2%")
    effective_from: datetime


class BlockedSlot(BaseModel):
    start_at: datetime
    end_at: datetime


class ListingDetail(ListingCard):
    description: str
    condition: Condition
    manufacture_date: date | None
    photos: list[PhotoOut]
    owner: OwnerCard  # type: ignore[assignment]
    asset: AssetOut
    late_fee_rule: LateFeeRuleOut | None = Field(description="Shown on every rent listing")
    unavailable: list[BlockedSlot] = Field(description="Approved bookings block these slots")
    is_mine: bool
    can_edit: bool = Field(description="False while a booking is approved or active")
    pending_request_count: int | None = Field(None, description="Owner only")
