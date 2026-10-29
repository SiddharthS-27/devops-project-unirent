import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.core.schemas import PhotoOut
from app.modules.listings.schemas import LateFeeRuleOut, ListingCard, ListingKind
from app.modules.profiles.schemas import ProfileView

BookingStatus = Literal[
    "requested",
    "approved",
    "declined",
    "withdrawn",
    "expired",
    "cancelled",
    "active",
    "overdue",
    "returning",
    "in_appeal",
    "awaiting_reviews",
    "completed",
]
BookingGroup = Literal["pending", "upcoming", "active", "past", "cancelled"]
BookingRole = Literal["renter", "owner"]
PaymentMethod = Literal["upi", "cash"]
PaymentStatus = Literal[
    "created", "pending", "captured", "failed", "marked_paid", "refunded", "partly_refunded"
]
PaymentPurpose = Literal["rent", "extension", "return_charges", "sale"]


class BookingCreate(BaseModel):
    listing_id: uuid.UUID
    start_at: datetime | None = Field(None, description="Rent only")
    end_at: datetime | None = Field(None, description="Rent only")


class QuoteOut(BaseModel):
    """The request summary: what the renter will pay, before sending."""

    listing_id: uuid.UUID
    kind: ListingKind
    start_at: datetime | None
    end_at: datetime | None
    hours: int | None
    amount_paise: int
    late_fee_rule: LateFeeRuleOut | None


class DeclineIn(BaseModel):
    reason: str | None = Field(None, max_length=500)


class CancelIn(BaseModel):
    note: str = Field(min_length=5, max_length=1000, description="Sent to the other side")


class CancellationRatingIn(BaseModel):
    stars: int = Field(ge=1, le=5)
    comment: str = Field(min_length=2, max_length=1000)


class PhotosIn(BaseModel):
    object_keys: list[str] = Field(min_length=1, max_length=8)


class PaymentStartIn(BaseModel):
    method: PaymentMethod


class PaymentItem(BaseModel):
    label: str
    amount_paise: int


class RazorpayCheckout(BaseModel):
    """Everything Razorpay Checkout needs to open."""

    key_id: str
    order_id: str
    amount_paise: int
    currency: str = "INR"
    name: str
    description: str
    prefill_email: str | None = None
    prefill_contact: str | None = None


class PaymentOut(BaseModel):
    id: uuid.UUID
    purpose: PaymentPurpose
    method: PaymentMethod
    status: PaymentStatus
    amount_paise: int
    items: list[PaymentItem]
    checkout: RazorpayCheckout | None = Field(description="UPI only, while pending")
    created_at: datetime
    captured_at: datetime | None


class OtpOut(BaseModel):
    """Shown on one phone, typed into the other. Valid 15 minutes, 5 tries."""

    code: str
    expires_at: datetime


class OtpIn(BaseModel):
    code: str = Field(pattern=r"^\d{6}$")


class TimelineStep(BaseModel):
    key: str
    label: str
    state: Literal["done", "current", "upcoming", "skipped"]
    at: datetime | None = None


class NextAction(BaseModel):
    """The one thing due next, for the action card."""

    key: str = Field(examples=["upload_pickup_photos", "pay", "show_otp", "enter_otp"])
    label: str
    by_me: bool = Field(description="False when waiting for the other side")


class HandoverSide(BaseModel):
    photos: list[PhotoOut]
    done: bool


class Handover(BaseModel):
    phase: Literal["pickup", "return"]
    renter: HandoverSide
    owner: HandoverSide
    otp_ready: bool = Field(description="Photos and payment are done; the code can be shown")
    otp_shown_by: BookingRole
    otp_verified_at: datetime | None


class ExtensionIn(BaseModel):
    new_end_at: datetime


class ExtensionOut(BaseModel):
    id: uuid.UUID
    new_end_at: datetime
    status: Literal["requested", "approved", "declined"]
    amount_paise: int
    payment: PaymentOut | None
    pay_in_cash_at_return: bool
    created_at: datetime


class DamageChargeIn(BaseModel):
    amount_paise: int = Field(gt=0)
    description: str = Field(min_length=3, max_length=1000)


class Charges(BaseModel):
    """What the renter owes at return. The late fee is live while unpaid."""

    late_fee_paise: int
    overdue_minutes: int
    damage_paise: int
    damage_description: str | None
    cash_extensions_paise: int
    total_paise: int
    paid: bool
    payment: PaymentOut | None


class CancellationInfo(BaseModel):
    by: BookingRole
    note: str
    at: datetime
    rating_due: bool = Field(description="True when you should now rate the canceller")


class AppealRef(BaseModel):
    id: uuid.UUID
    status: Literal["open", "ruled", "overruled"]


class ReviewState(BaseModel):
    mine_submitted: bool
    theirs_submitted: bool
    revealed: bool
    release_at: datetime | None


class BookingSummary(BaseModel):
    id: uuid.UUID
    kind: ListingKind
    status: BookingStatus
    role: BookingRole
    listing_id: uuid.UUID
    listing_title: str
    listing_photo_url: str | None
    counterparty_id: uuid.UUID
    counterparty_name: str
    start_at: datetime | None
    end_at: datetime | None
    amount_paise: int
    next_action: NextAction | None
    updated_at: datetime


class BookingOut(BaseModel):
    id: uuid.UUID
    kind: ListingKind
    status: BookingStatus
    role: BookingRole | Literal["staff"]
    listing: ListingCard
    renter: ProfileView
    owner: ProfileView
    start_at: datetime | None
    end_at: datetime | None
    amount_paise: int = Field(description="Rent or sale price, locked at approval")
    late_fee_rule: LateFeeRuleOut | None
    timeline: list[TimelineStep]
    next_action: NextAction | None
    pickup: Handover | None
    return_: Handover | None = Field(alias="return", serialization_alias="return")
    payments: list[PaymentOut]
    extensions: list[ExtensionOut]
    charges: Charges | None
    cancellation: CancellationInfo | None
    appeal: AppealRef | None
    reviews: ReviewState | None
    overdue_since: datetime | None
    escalation_available_at: datetime | None
    can_cancel: bool
    can_escalate: bool
    can_appeal: bool
    server_now: datetime
    created_at: datetime

    model_config = {"populate_by_name": True}


class EscalateIn(BaseModel):
    note: str | None = Field(None, max_length=1000)


class AppealCreate(BaseModel):
    reason: Literal["damage_dispute", "item_mismatch", "other"]
    notes: str = Field(min_length=5, max_length=2000)
    photo_keys: list[str] = Field([], max_length=8)


class AppealOut(BaseModel):
    id: uuid.UUID
    booking_id: uuid.UUID
    status: Literal["open", "ruled", "overruled"]
    reason: str
    notes: str
    filed_by: BookingRole
    created_at: datetime


class ReviewParameter(BaseModel):
    key: str
    label: str


class ReviewForm(BaseModel):
    review_type: Literal["renter", "lender", "renter_sale", "lender_sale", "cancellation"]
    parameters: list[ReviewParameter]
    counterparty_id: uuid.UUID
    counterparty_name: str


class ReviewIn(BaseModel):
    ratings: dict[str, int] = Field(description="Parameter key to 1-5 stars")
    comment: str = Field(min_length=2, max_length=1000)
