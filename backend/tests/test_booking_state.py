import asyncio
import uuid
from datetime import timedelta

import pytest
from sqlalchemy.exc import IntegrityError

from app.core.clock import now
from app.core.db import get_sessionmaker
from app.core.errors import ApiError
from app.modules.bookings.models import Booking
from app.modules.bookings.state import can_move, transition
from tests.conftest import create_listing, lister


def _booking(kind="rent", status="requested") -> Booking:
    return Booking(id=uuid.uuid4(), kind=kind, status=status)


@pytest.mark.parametrize(
    "kind, frm, to, ok",
    [
        ("rent", "requested", "approved", True),
        ("rent", "requested", "active", False),
        ("rent", "approved", "active", True),
        ("rent", "approved", "awaiting_reviews", False),
        ("sale", "approved", "awaiting_reviews", True),
        ("sale", "approved", "active", False),
        ("rent", "approved", "cancelled", True),
        ("rent", "active", "cancelled", False),
        ("rent", "active", "overdue", True),
        ("rent", "overdue", "returning", True),
        ("rent", "returning", "in_appeal", True),
        ("rent", "returning", "awaiting_reviews", True),
        ("rent", "awaiting_reviews", "completed", True),
        ("rent", "completed", "in_appeal", False),
        ("sale", "completed", "in_appeal", True),
        ("rent", "declined", "approved", False),
    ],
)
def test_transition_table(kind, frm, to, ok):
    assert can_move(_booking(kind, frm), to) is ok


def test_transition_records_the_move():
    class S:
        added = []

        def add(self, obj):
            self.added.append(obj)

    booking = _booking()
    session = S()
    transition(session, booking, "approved", actor_id=None, actor_role="owner", action="approve")
    assert booking.status == "approved"
    assert session.added[0].from_status == "requested" and session.added[0].to_status == "approved"
    with pytest.raises(ApiError):
        transition(session, booking, "requested", actor_id=None, actor_role="owner", action="x")


async def test_overlapping_approvals_cannot_both_hold_the_slot(api):
    owner = await lister(api)
    listing = await create_listing(owner)
    start = now() + timedelta(days=2)

    async def approve_one(offset_hours: int):
        async with get_sessionmaker()() as session:
            renter = uuid.uuid4()
            session.add(
                Booking(
                    id=uuid.uuid4(),
                    listing_id=listing["id"],
                    asset_id=listing["asset"]["id"],
                    kind="rent",
                    status="approved",
                    renter_id=renter,
                    owner_id=owner.id,
                    start_at=start + timedelta(hours=offset_hours),
                    end_at=start + timedelta(hours=offset_hours + 5),
                    amount_paise=1000,
                    listing_title="x",
                    pickup_point="x",
                    created_at=now(),
                    updated_at=now(),
                )
            )
            await session.commit()

    results = await asyncio.gather(*(approve_one(h) for h in (0, 1, 2)), return_exceptions=True)
    assert sum(r is None for r in results) == 1
    assert all(isinstance(r, IntegrityError) for r in results if r is not None)
    await approve_one(7)  # a slot after all three is free
