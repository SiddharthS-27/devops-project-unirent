import uuid
from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Query
from sqlalchemy import func, select
from unirent_payments import success_rate
from unirent_security import AdminAccount, audit

from app.core import clock
from app.core.config import get_settings
from app.core.deps import SessionDep
from app.core.errors import ApiError
from app.core.redis import get_redis
from app.core.schemas import Page
from app.modules.admin.schemas import AuditEntryOut, ClockIn, ClockOut, MetricsOut
from app.modules.bookings.models import Booking
from app.modules.listings.models import Listing
from app.modules.moderation.models import Appeal
from app.modules.profiles.models import Profile

router = APIRouter(prefix="/admin", tags=["admin"])

CLOCK_KEY = "clock:offset_seconds"
CLOCK_ENVIRONMENTS = ("dev", "test", "staging")


@router.get("/metrics", response_model=MetricsOut)
async def metrics(admin: AdminAccount, session: SessionDep):
    """Platform health for the admin's metrics screen."""
    by_state = dict(
        (await session.execute(select(Booking.status, func.count()).group_by(Booking.status))).all()
    )
    return MetricsOut(
        active_listings=await session.scalar(select(func.count()).where(Listing.status == "active"))
        or 0,
        bookings_by_state=by_state,
        payment_success_rate=await success_rate(),
        open_disputes=await session.scalar(select(func.count()).where(Appeal.status == "open"))
        or 0,
        overdue_count=by_state.get("overdue", 0),
        students=await session.scalar(select(func.count()).select_from(Profile)) or 0,
        completed_trades=by_state.get("completed", 0),
    )


@router.get("/audit-log", response_model=Page[AuditEntryOut])
async def audit_log(
    admin: AdminAccount,
    actor_id: uuid.UUID | None = None,
    target: str | None = None,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
):
    """Every staff action, newest first. Read only: the log can't be edited."""
    before = int(cursor) if cursor and cursor.isdigit() else None
    rows = await audit.entries(actor_id=actor_id, target=target, before_id=before, limit=limit)
    next_cursor = str(rows[-1]["id"]) if len(rows) == limit else None
    return Page[AuditEntryOut](items=[AuditEntryOut(**r) for r in rows], next_cursor=next_cursor)


def _clock_allowed() -> None:
    if get_settings().environment not in CLOCK_ENVIRONMENTS:
        raise ApiError(403, "CLOCK_LOCKED", "The clock can only be moved on staging")


def _clock_out() -> ClockOut:
    return ClockOut(now=clock.now(), offset_minutes=int(clock.get_offset().total_seconds() // 60))


async def load_clock_offset() -> None:
    """At startup, pick up an offset set before a restart (staging only)."""
    if get_settings().environment not in CLOCK_ENVIRONMENTS:
        return
    stored = await get_redis().get(CLOCK_KEY)
    if stored:
        clock.set_offset(timedelta(seconds=int(stored)))


@router.get("/clock", response_model=ClockOut)
async def get_clock(admin: AdminAccount):
    _clock_allowed()
    return _clock_out()


@router.post("/clock", response_model=ClockOut)
async def set_clock(body: ClockIn, admin: AdminAccount):
    """Staging only: move the clock forward for the demo (for example to an overdue
    rental). Timers that fall due fire on the timer runner's next pass."""
    _clock_allowed()
    offset = timedelta(minutes=body.offset_minutes)
    clock.set_offset(offset)
    await get_redis().set(CLOCK_KEY, int(offset.total_seconds()))
    await audit.record(admin, "admin.clock_set", "clock", {"offset_minutes": body.offset_minutes})
    return _clock_out()
