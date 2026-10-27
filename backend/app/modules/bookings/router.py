import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Query
from unirent_security import CurrentAccount

from app.core.deps import IdempotencyKey, SessionDep
from app.core.errors import not_implemented
from app.core.schemas import Page
from app.modules.bookings.schemas import (
    AppealCreate,
    AppealOut,
    BookingCreate,
    BookingGroup,
    BookingOut,
    BookingRole,
    BookingSummary,
    CancelIn,
    CancellationRatingIn,
    DamageChargeIn,
    DeclineIn,
    EscalateIn,
    ExtensionIn,
    ExtensionOut,
    OtpIn,
    OtpOut,
    PaymentOut,
    PaymentStartIn,
    PhotosIn,
    QuoteOut,
    ReviewForm,
    ReviewIn,
    ReviewState,
)

router = APIRouter(prefix="/bookings", tags=["bookings"])
B = "/{booking_id}"


@router.get("/quote", response_model=QuoteOut)
async def quote(
    account: CurrentAccount,
    session: SessionDep,
    listing_id: uuid.UUID,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
):
    """The request summary: total rent, the late-fee rule and the grace period."""
    raise not_implemented()


@router.post("", response_model=BookingOut, status_code=201)
async def request_booking(
    body: BookingCreate, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    """Request to rent or buy. Expires if the owner doesn't answer in 24 hours."""
    raise not_implemented()


@router.get("", response_model=Page[BookingSummary])
async def list_bookings(
    account: CurrentAccount,
    session: SessionDep,
    role: BookingRole = "renter",
    group: BookingGroup | None = None,
    listing_id: uuid.UUID | None = None,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
):
    """My bookings as renter or buyer, or as owner or seller (incoming requests)."""
    raise not_implemented()


@router.get(B, response_model=BookingOut, response_model_by_alias=True)
async def get_booking(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.post(B + "/approve", response_model=BookingOut)
async def approve(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    """Owner approves. Overlapping pending requests are auto-declined."""
    raise not_implemented()


@router.post(B + "/decline", response_model=BookingOut)
async def decline(
    booking_id: uuid.UUID,
    body: DeclineIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    raise not_implemented()


@router.post(B + "/withdraw", response_model=BookingOut)
async def withdraw(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.post(B + "/cancel", response_model=BookingOut)
async def cancel(
    booking_id: uuid.UUID,
    body: CancelIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Either side, after approval and before the pickup OTP. The note goes to the other side."""
    raise not_implemented()


@router.post(B + "/cancellation-rating", response_model=BookingOut)
async def rate_cancellation(
    booking_id: uuid.UUID, body: CancellationRatingIn, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.post(B + "/pickup/photos", response_model=BookingOut)
async def pickup_photos(
    booking_id: uuid.UUID, body: PhotosIn, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.post(B + "/pickup/payment", response_model=PaymentOut)
async def pickup_payment(
    booking_id: uuid.UUID,
    body: PaymentStartIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Renter pays rent (or the sale price): UPI opens Razorpay Checkout; cash waits
    for the owner to mark it received."""
    raise not_implemented()


@router.post(B + "/pickup/otp", response_model=OtpOut)
async def pickup_otp(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    """Renter's phone shows this code once photos and payment are done."""
    raise not_implemented()


@router.post(B + "/pickup/otp/verify", response_model=BookingOut)
async def verify_pickup_otp(
    booking_id: uuid.UUID,
    body: OtpIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Owner types the renter's code. The rental becomes Active (a sale completes)."""
    raise not_implemented()


@router.post(B + "/extensions", response_model=ExtensionOut, status_code=201)
async def request_extension(
    booking_id: uuid.UUID,
    body: ExtensionIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    raise not_implemented()


@router.post(B + "/extensions/{extension_id}/approve", response_model=ExtensionOut)
async def approve_extension(
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    raise not_implemented()


@router.post(B + "/extensions/{extension_id}/decline", response_model=ExtensionOut)
async def decline_extension(
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    raise not_implemented()


@router.post(B + "/extensions/{extension_id}/payment", response_model=PaymentOut)
async def pay_extension(
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    body: PaymentStartIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """UPI now, or cash, which is added to the charges at return."""
    raise not_implemented()


@router.post(B + "/return/start", response_model=BookingOut)
async def start_return(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.post(B + "/return/photos", response_model=BookingOut)
async def return_photos(
    booking_id: uuid.UUID, body: PhotosIn, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.post(B + "/return/otp", response_model=OtpOut)
async def return_otp(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    """Owner's phone shows this code after both sides' return photos."""
    raise not_implemented()


@router.post(B + "/return/otp/verify", response_model=BookingOut)
async def verify_return_otp(
    booking_id: uuid.UUID,
    body: OtpIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Renter types the owner's code, confirming the item is back."""
    raise not_implemented()


@router.post(B + "/damage-charge", response_model=BookingOut)
async def record_damage_charge(
    booking_id: uuid.UUID,
    body: DamageChargeIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Owner records the charge both sides agreed on. Either side may appeal instead."""
    raise not_implemented()


@router.post(B + "/return/payment", response_model=PaymentOut)
async def pay_return_charges(
    booking_id: uuid.UUID,
    body: PaymentStartIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Late fee, damage charge and any cash extensions, itemised."""
    raise not_implemented()


@router.post(B + "/proceed", response_model=BookingOut)
async def proceed(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    """Owner closes the return once charges are paid. Reviews open."""
    raise not_implemented()


@router.post(B + "/escalate", response_model=BookingOut)
async def escalate(
    booking_id: uuid.UUID, body: EscalateIn, account: CurrentAccount, session: SessionDep
):
    """Owner, one hour or more into overdue."""
    raise not_implemented()


@router.post(B + "/appeals", response_model=AppealOut, status_code=201)
async def file_appeal(
    booking_id: uuid.UUID,
    body: AppealCreate,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Handover photos attach automatically."""
    raise not_implemented()


@router.get(B + "/review-form", response_model=ReviewForm)
async def review_form(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.post(B + "/reviews", response_model=ReviewState, status_code=201)
async def submit_review(
    booking_id: uuid.UUID, body: ReviewIn, account: CurrentAccount, session: SessionDep
):
    """Blind: hidden until both sides submit or 24 hours pass."""
    raise not_implemented()
