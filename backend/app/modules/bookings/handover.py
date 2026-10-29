"""In-person handovers: photos from both sides, the payment, then a one-time code.
At pickup the renter's phone shows the code and the owner types it; at return
it is the other way round."""

import secrets
import uuid
from datetime import timedelta

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import PaymentView, payment_status, start_payment
from unirent_security import AccountContext, hash_secret, rate_limit_hit, verify_secret

from app.core import storage
from app.core.clock import now
from app.core.errors import ApiError
from app.modules.bookings.models import Booking, HandoverOtp, HandoverPhoto
from app.modules.bookings.service import get_booking, require_party
from app.modules.bookings.state import record, require_status

OTP_TTL = timedelta(minutes=15)
MAX_PHOTOS_PER_SIDE = 8
PHASE_STATUS = {"pickup": "approved", "return": "returning"}
# Who shows the code in each phase; the other side types it.
SHOWS_CODE = {"pickup": "renter", "return": "owner"}


def _locked(message: str) -> ApiError:
    return ApiError(409, "STEP_LOCKED", message)


async def photo_keys(
    session: AsyncSession, booking_id: uuid.UUID
) -> dict[tuple[str, str], list[str]]:
    rows = await session.execute(
        select(HandoverPhoto.phase, HandoverPhoto.side, HandoverPhoto.object_key)
        .where(HandoverPhoto.booking_id == booking_id)
        .order_by(HandoverPhoto.created_at)
    )
    out: dict[tuple[str, str], list[str]] = {}
    for phase, side, key in rows:
        out.setdefault((phase, side), []).append(key)
    return out


async def add_photos(
    session: AsyncSession, booking_id: uuid.UUID, actor: AccountContext, phase: str, keys: list[str]
) -> Booking:
    booking = await get_booking(session, booking_id, actor, lock=True)
    side = booking.role_of(actor.id)
    if side is None:
        raise ApiError(403, "NOT_YOUR_STEP", "Only the two sides upload handover photos")
    require_status(booking, PHASE_STATUS[phase])
    existing = await session.scalar(
        select(func.count()).where(
            HandoverPhoto.booking_id == booking.id,
            HandoverPhoto.phase == phase,
            HandoverPhoto.side == side,
        )
    )
    if (existing or 0) + len(keys) > MAX_PHOTOS_PER_SIDE:
        raise ApiError(422, "TOO_MANY_PHOTOS", f"Up to {MAX_PHOTOS_PER_SIDE} photos each")
    for key in keys:
        await storage.confirm_upload(key, "handover", actor.id)
        session.add(
            HandoverPhoto(
                id=uuid.uuid4(), booking_id=booking.id, phase=phase, side=side, object_key=key
            )
        )
    record(session, booking, actor.id, side, f"{phase}_photos", details={"count": len(keys)})
    return booking


def handover_purpose(booking: Booking) -> str:
    return "rent" if booking.kind == "rent" else "sale"


async def pickup_payment(
    session: AsyncSession,
    booking_id: uuid.UUID,
    renter: AccountContext,
    method: str,
    idempotency_key: str,
) -> PaymentView:
    """The renter pays the locked rent (or sale price) after both sides' photos."""
    booking = await get_booking(session, booking_id, renter, lock=True)
    require_party(booking, renter, "renter")
    require_status(booking, "approved")
    if renter.status == "suspended":
        raise ApiError(403, "ACCOUNT_SUSPENDED", "Your account is suspended")
    photos = await photo_keys(session, booking.id)
    if not (photos.get(("pickup", "renter")) and photos.get(("pickup", "owner"))):
        raise _locked("Both of you upload pickup photos first")
    label = "Rent" if booking.kind == "rent" else "Sale price"
    return await start_payment(
        booking.id,
        handover_purpose(booking),
        booking.renter_id,
        booking.owner_id,
        booking.amount_paise,
        method,
        idempotency_key,
        items=[{"label": label, "amount_paise": booking.amount_paise}],
    )


async def _new_code(session: AsyncSession, booking: Booking, phase: str) -> tuple[str, HandoverOtp]:
    await session.execute(
        update(HandoverOtp)
        .where(
            HandoverOtp.booking_id == booking.id,
            HandoverOtp.phase == phase,
            HandoverOtp.used_at.is_(None),
        )
        .values(replaced=True)
    )
    code = f"{secrets.randbelow(1_000_000):06d}"
    otp = HandoverOtp(
        id=uuid.uuid4(),
        booking_id=booking.id,
        phase=phase,
        code_hash=hash_secret(code),
        expires_at=now() + OTP_TTL,
        created_at=now(),
    )
    session.add(otp)
    return code, otp


async def show_code(
    session: AsyncSession, booking_id: uuid.UUID, actor: AccountContext, phase: str, ready: bool
) -> tuple[str, HandoverOtp]:
    """A fresh code for the side that shows it. Asking again replaces the old one."""
    booking = await get_booking(session, booking_id, actor, lock=True)
    require_party(booking, actor, SHOWS_CODE[phase])
    require_status(booking, PHASE_STATUS[phase])
    if not ready:
        raise _locked("Finish the earlier steps first")
    code, otp = await _new_code(session, booking, phase)
    record(session, booking, actor.id, SHOWS_CODE[phase], f"{phase}_code_shown")
    return code, otp


async def pickup_ready(session: AsyncSession, booking: Booking) -> bool:
    photos = await photo_keys(session, booking.id)
    if not (photos.get(("pickup", "renter")) and photos.get(("pickup", "owner"))):
        return False
    payment = await payment_status(booking.id, handover_purpose(booking))
    return payment is not None and payment.is_paid


async def check_code(
    session: AsyncSession, booking: Booking, actor: AccountContext, phase: str, code: str
) -> None:
    """The typing side enters the code: 5 tries per code, then a new one is needed."""
    typer = "owner" if SHOWS_CODE[phase] == "renter" else "renter"
    require_party(booking, actor, typer)
    require_status(booking, PHASE_STATUS[phase])
    otp = await session.scalar(
        select(HandoverOtp)
        .where(
            HandoverOtp.booking_id == booking.id,
            HandoverOtp.phase == phase,
            HandoverOtp.used_at.is_(None),
            HandoverOtp.replaced.is_(False),
        )
        .order_by(HandoverOtp.created_at.desc())
        .limit(1)
        .with_for_update()
    )
    if otp is None:
        raise _locked("Ask the other side to show their code")
    if otp.expires_at < now():
        raise ApiError(409, "CODE_EXPIRED", "The code expired; ask for a new one")
    await rate_limit_hit("otp_entry", f"otp:{otp.id}")
    if not verify_secret(code, otp.code_hash):
        record(session, booking, actor.id, typer, f"{phase}_code_wrong")
        await session.commit()
        raise ApiError(422, "WRONG_CODE", "That code is not right")
    otp.used_at = now()
