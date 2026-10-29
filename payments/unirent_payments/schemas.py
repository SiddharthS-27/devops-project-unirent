import uuid
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


PaymentMethod = Literal["upi", "cash"]
PaymentStatus = Literal[
    "created", "pending", "captured", "failed", "marked_paid", "refunded", "partly_refunded"
]
PaymentPurpose = Literal["rent", "extension", "return_charges", "sale"]


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


class VerifyIn(BaseModel):
    """What Razorpay Checkout returns to the app on success."""

    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class WebhookAck(BaseModel):
    status: Literal["processed", "duplicate", "ignored"]


class LateFeeRuleOut(BaseModel):
    id: uuid.UUID
    grace_minutes: int
    base_fee_paise: int
    hourly_percent_bp: int = Field(description="Basis points of the rent per hour: 200 = 2%")
    effective_from: datetime
