import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.core.schemas import PhotoOut
from app.modules.bookings.schemas import AppealOut, BookingOut, BookingSummary
from app.modules.profiles.schemas import ProfileStaff, Residence


class TrustPenalty(BaseModel):
    account_id: uuid.UUID
    role: Literal["lender", "renter"]
    points: int = Field(ge=1, le=50)


class AccountAction(BaseModel):
    account_id: uuid.UUID
    status: Literal["suspended", "banned"]


class RulingIn(BaseModel):
    """Any combination of outcomes. The booking then moves on to reviews."""

    summary: str = Field(min_length=5, max_length=2000, description="Sent to both sides")
    charge_paise: int | None = Field(None, ge=0, description="Damage charge the renter owes")
    refund_paise: int | None = Field(None, gt=0, description="Refund to the renter or buyer")
    trust_penalty: TrustPenalty | None = None
    remove_listing: bool = False
    account_action: AccountAction | None = None


class RulingOut(RulingIn):
    id: uuid.UUID
    ruled_by: uuid.UUID
    ruled_at: datetime
    overrules: uuid.UUID | None = None


class AppealSummary(BaseModel):
    id: uuid.UUID
    booking_id: uuid.UUID
    kind: Literal["rent", "sale"]
    listing_title: str
    reason: str
    status: Literal["open", "ruled", "overruled"]
    filed_by_name: str
    created_at: datetime


class AppealDetail(BaseModel):
    appeal: AppealOut
    booking: BookingOut
    pickup_photos: list[PhotoOut]
    return_photos: list[PhotoOut]
    extra_photos: list[PhotoOut]
    rulings: list[RulingOut]


class EscalationOut(BaseModel):
    booking: BookingSummary
    kind: Literal["overdue", "stalled_proceed", "owner_escalated"]
    since: datetime
    renter_id: uuid.UUID
    renter_name: str
    renter_phone: str | None
    renter_residence: Residence | None
    owner_name: str
    owner_phone: str | None
    note: str | None


RiskKind = Literal["overdue_returns", "cancellations", "disputes", "low_trust"]


class RiskFlag(BaseModel):
    kind: RiskKind
    count: int
    window_days: int | None


class StaffUserRow(BaseModel):
    account_id: uuid.UUID
    full_name: str | None
    email: str
    status: str
    lender_trust: int | None
    renter_trust: int | None
    risk_flags: list[RiskFlag]


class PenaltyOut(BaseModel):
    role: Literal["lender", "renter"]
    points: int
    reason: str
    by: uuid.UUID
    at: datetime


class StaffUserDetail(BaseModel):
    profile: ProfileStaff | None
    email: str
    status: str
    bookings: list[BookingSummary]
    risk_flags: list[RiskFlag]
    penalties: list[PenaltyOut]


class StatusChangeIn(BaseModel):
    status: Literal["active", "suspended", "banned"]
    reason: str = Field(min_length=3, max_length=1000)


class PenaltyIn(BaseModel):
    role: Literal["lender", "renter"]
    points: int = Field(ge=1, le=50)
    reason: str = Field(min_length=3, max_length=1000)


class ReasonIn(BaseModel):
    reason: str = Field(min_length=3, max_length=1000)
