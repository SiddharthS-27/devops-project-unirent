import uuid
from datetime import datetime
from typing import Annotated, Literal, Self

from pydantic import BaseModel, Field, model_validator

ResidenceType = Literal["hostel", "day_scholar"]


class ProfileIn(BaseModel):
    """Everything on the onboarding form. The college email comes from sign-in."""

    full_name: str = Field(min_length=2, max_length=200)
    photo_key: str | None = Field(None, max_length=300, description="From POST /uploads/photos")
    roll_number: str = Field(min_length=1, max_length=50)
    department: str = Field(min_length=1, max_length=100)
    year: int = Field(ge=1, le=6)
    residence_type: ResidenceType
    hostel_name: str | None = Field(None, max_length=100)
    room_number: str | None = Field(None, max_length=20)
    home_address: str | None = Field(None, max_length=500)

    @model_validator(mode="after")
    def residence_matches_type(self) -> Self:
        if self.residence_type == "hostel":
            if not (self.hostel_name and self.room_number):
                raise ValueError("hostel students give a hostel name and room number")
            self.home_address = None
        else:
            if not self.home_address:
                raise ValueError("day scholars give a home address")
            self.hostel_name = self.room_number = None
        return self


class TermsIn(BaseModel):
    version: str = Field(description="The terms version the student read and accepted")


class Residence(BaseModel):
    type: ResidenceType
    hostel_name: str | None
    room_number: str | None
    home_address: str | None


class TrustSummary(BaseModel):
    score: int | None = Field(None, description="0-100; null until 5 completed trades")
    rating: float | None = Field(None, description="Average overall rating, 1-5")
    review_count: int = 0


class ProfilePublic(BaseModel):
    """What everyone sees."""

    view: Literal["public"] = "public"
    account_id: uuid.UUID
    full_name: str
    photo_url: str | None
    department: str
    year: int
    phone: str | None
    lender: TrustSummary
    renter: TrustSummary
    is_new: bool = Field(description="Fewer than 5 completed trades: show the New badge")
    completed_trades: int
    cancellation_count: int
    member_since: datetime


class ProfileCounterparty(ProfilePublic):
    """The other side of an approved booking also sees where to find them."""

    view: Literal["counterparty"] = "counterparty"  # type: ignore[assignment]
    residence: Residence


class ProfileStaff(ProfileCounterparty):
    view: Literal["staff"] = "staff"  # type: ignore[assignment]
    email: str
    roll_number: str
    status: str


class ProfileOwn(ProfileStaff):
    view: Literal["own"] = "own"  # type: ignore[assignment]
    photo_key: str | None


class AccountSummary(BaseModel):
    id: uuid.UUID
    email: str
    role: str
    status: str


class Onboarding(BaseModel):
    profile_complete: bool
    phone_verified: bool
    terms_accepted: bool
    complete: bool


class MeOut(BaseModel):
    account: AccountSummary
    profile: ProfileOwn | None
    onboarding: Onboarding
    current_terms_version: str


ProfileView = Annotated[
    ProfileOwn | ProfileStaff | ProfileCounterparty | ProfilePublic, Field(discriminator="view")
]
