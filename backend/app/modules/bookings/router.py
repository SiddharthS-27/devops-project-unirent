import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Query
from unirent_payments.api import payment_out
from unirent_security import ActiveAccount, CurrentAccount

from app.core.deps import IdempotencyKey, SessionDep
from app.core.errors import ApiError, not_implemented
from app.core.schemas import Page
from app.modules.bookings import handover, pricing, rental, returns, service, views
from app.modules.bookings.models import Extension
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
from app.modules.listings.service import current_late_fee_rule, get_listing
from app.modules.profiles.service import OnboardedStudent

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
    listing = await get_listing(session, listing_id)
    hours, amount = pricing.quote(listing, start_at, end_at)
    return QuoteOut(
        listing_id=listing.id,
        kind=listing.kind,  # type: ignore[arg-type]
        start_at=start_at,
        end_at=end_at,
        hours=hours,
        amount_paise=amount,
        late_fee_rule=await current_late_fee_rule() if listing.kind == "rent" else None,
    )


@router.post("", response_model=BookingOut, status_code=201)
async def request_booking(
    body: BookingCreate, key: IdempotencyKey, account: OnboardedStudent, session: SessionDep
):
    """Request to rent or buy. Expires if the owner doesn't answer in 24 hours."""
    booking = await service.request(session, account, body.listing_id, body.start_at, body.end_at)
    await session.commit()
    return await views.booking_out(session, booking, account)


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
    return await views.summaries(
        session, account, role=role, group=group, listing_id=listing_id, cursor=cursor, limit=limit
    )


@router.get(B, response_model=BookingOut, response_model_by_alias=True)
async def get_booking(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    booking = await service.get_booking(session, booking_id, account)
    return await views.booking_out(session, booking, account)


@router.post(B + "/approve", response_model=BookingOut)
async def approve(
    booking_id: uuid.UUID, key: IdempotencyKey, account: ActiveAccount, session: SessionDep
):
    """Owner approves. The price locks, and overlapping pending requests are auto-declined."""
    booking = await service.approve(session, booking_id, account)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/decline", response_model=BookingOut)
async def decline(
    booking_id: uuid.UUID,
    body: DeclineIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    booking = await service.decline(session, booking_id, account, body.reason)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/withdraw", response_model=BookingOut)
async def withdraw(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    """The renter withdraws a pending request. It doesn't count as a cancellation."""
    booking = await service.withdraw(session, booking_id, account)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/cancel", response_model=BookingOut)
async def cancel(
    booking_id: uuid.UUID,
    body: CancelIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Either side, after approval and before the pickup OTP. The note goes to the other side."""
    booking = await service.cancel(session, booking_id, account, body.note)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/cancellation-rating", response_model=BookingOut)
async def rate_cancellation(
    booking_id: uuid.UUID, body: CancellationRatingIn, account: CurrentAccount, session: SessionDep
):
    """The side that didn't cancel reads the note and rates the canceller."""
    booking = await service.rate_cancellation(
        session, booking_id, account, body.stars, body.comment
    )
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/pickup/photos", response_model=BookingOut)
async def pickup_photos(
    booking_id: uuid.UUID, body: PhotosIn, account: CurrentAccount, session: SessionDep
):
    """Each side adds its own pickup photos (upload with purpose "handover" first)."""
    booking = await handover.add_photos(session, booking_id, account, "pickup", body.object_keys)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/pickup/payment", response_model=PaymentOut)
async def pickup_payment(
    booking_id: uuid.UUID,
    body: PaymentStartIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Renter pays rent (or the sale price): UPI opens Razorpay Checkout; cash waits
    for the owner to mark it received (POST /payments/{id}/mark-cash-paid)."""
    payment = await handover.pickup_payment(session, booking_id, account, body.method, key)
    return payment_out(payment)


@router.post(B + "/pickup/otp", response_model=OtpOut)
async def pickup_otp(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    """Renter's phone shows this code once photos and payment are done."""
    booking = await service.get_booking(session, booking_id, account)
    ready = await handover.pickup_ready(session, booking)
    code, otp = await handover.show_code(session, booking_id, account, "pickup", ready)
    await session.commit()
    return OtpOut(code=code, expires_at=otp.expires_at)


@router.post(B + "/pickup/otp/verify", response_model=BookingOut)
async def verify_pickup_otp(
    booking_id: uuid.UUID,
    body: OtpIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Owner types the renter's code. The rental becomes Active (a sale completes)."""
    booking = await service.get_booking(session, booking_id, account, lock=True)
    await handover.check_code(session, booking, account, "pickup", body.code)
    await service.complete_pickup(session, booking, account)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/extensions", response_model=ExtensionOut, status_code=201)
async def request_extension(
    booking_id: uuid.UUID,
    body: ExtensionIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Ask the owner for more time. Extra time costs the listing's rate."""
    extension = await rental.request_extension(session, booking_id, account, body.new_end_at)
    await session.commit()
    return await views.extension_out(extension)


@router.post(B + "/extensions/{extension_id}/approve", response_model=ExtensionOut)
async def approve_extension(
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Moves the end time and the reminders; the renter then pays."""
    extension = await rental.decide_extension(session, booking_id, extension_id, account, True)
    await session.commit()
    return await views.extension_out(extension)


@router.post(B + "/extensions/{extension_id}/decline", response_model=ExtensionOut)
async def decline_extension(
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    extension = await rental.decide_extension(session, booking_id, extension_id, account, False)
    await session.commit()
    return await views.extension_out(extension)


@router.post(B + "/extensions/{extension_id}/payment", response_model=ExtensionOut)
async def pay_extension(
    booking_id: uuid.UUID,
    extension_id: uuid.UUID,
    body: PaymentStartIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """UPI now (the extension's payment carries the Checkout details), or cash,
    which is added to the charges at return."""
    await rental.pay_extension(session, booking_id, extension_id, account, body.method, key)
    extension = await session.get(Extension, extension_id)
    return await views.extension_out(extension)


@router.post(B + "/return/start", response_model=BookingOut)
async def start_return(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    """The renter starts the return when the two meet."""
    booking = await returns.start_return(session, booking_id, account)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/return/photos", response_model=BookingOut)
async def return_photos(
    booking_id: uuid.UUID, body: PhotosIn, account: CurrentAccount, session: SessionDep
):
    """The renter's photos first, then the owner's inspection photos."""
    booking = await service.get_booking(session, booking_id, account)
    if booking.role_of(account.id) == "owner":
        await returns.owner_may_inspect(session, booking)
    booking = await handover.add_photos(session, booking_id, account, "return", body.object_keys)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/return/otp", response_model=OtpOut)
async def return_otp(booking_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    """Owner's phone shows this code after both sides' return photos."""
    booking = await service.get_booking(session, booking_id, account)
    ready = await returns.code_ready(session, booking) and booking.return_completed_at is None
    code, otp = await handover.show_code(session, booking_id, account, "return", ready)
    await session.commit()
    return OtpOut(code=code, expires_at=otp.expires_at)


@router.post(B + "/return/otp/verify", response_model=BookingOut)
async def verify_return_otp(
    booking_id: uuid.UUID,
    body: OtpIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Renter types the owner's code, confirming the item is back."""
    booking = await service.get_booking(session, booking_id, account, lock=True)
    if booking.return_completed_at is not None:
        raise ApiError(409, "BOOKING_STATE", "The return is already confirmed")
    await handover.check_code(session, booking, account, "return", body.code)
    await returns.complete_return(session, booking, account)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/damage-charge", response_model=BookingOut)
async def record_damage_charge(
    booking_id: uuid.UUID,
    body: DamageChargeIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Owner records the charge both sides agreed on. Either side may appeal instead."""
    booking = await returns.record_damage(
        session, booking_id, account, body.amount_paise, body.description
    )
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/return/payment", response_model=PaymentOut)
async def pay_return_charges(
    booking_id: uuid.UUID,
    body: PaymentStartIn,
    key: IdempotencyKey,
    account: CurrentAccount,
    session: SessionDep,
):
    """Late fee, damage charge and any cash extensions, itemised."""
    return payment_out(await returns.pay_charges(session, booking_id, account, body.method, key))


@router.post(B + "/proceed", response_model=BookingOut)
async def proceed(
    booking_id: uuid.UUID, key: IdempotencyKey, account: CurrentAccount, session: SessionDep
):
    """Owner closes the return once charges are paid. Reviews open."""
    booking = await returns.proceed(session, booking_id, account)
    await session.commit()
    return await views.booking_out(session, booking, account)


@router.post(B + "/escalate", response_model=BookingOut)
async def escalate(
    booking_id: uuid.UUID, body: EscalateIn, account: CurrentAccount, session: SessionDep
):
    """Owner, one hour or more into overdue."""
    booking = await rental.escalate(session, booking_id, account, body.note)
    await session.commit()
    return await views.booking_out(session, booking, account)


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
