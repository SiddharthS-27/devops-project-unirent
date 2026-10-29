from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field

PayoutStatus = Literal[
    "none", "created", "under_review", "needs_clarification", "activated", "suspended"
]


class PayoutAccountIn(BaseModel):
    """Sent to Razorpay to create the linked account; never stored by UniRent."""

    legal_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    phone: str = Field(pattern=r"^\+91[6-9]\d{9}$")
    account_number: str = Field(pattern=r"^\d{9,18}$")
    ifsc: str = Field(pattern=r"^[A-Z]{4}0[A-Z0-9]{6}$")
    beneficiary_name: str = Field(min_length=2, max_length=120)


class PayoutAccountOut(BaseModel):
    status: PayoutStatus
    ready: bool = Field(description="True when listings can be posted")
    razorpay_account_id: str | None = None
    updated_at: datetime | None = None
