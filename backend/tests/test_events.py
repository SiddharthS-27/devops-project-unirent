"""Events the backend emits must match their schemas in contracts/events/."""

import json
from pathlib import Path

import pytest

EVENTS = Path(__file__).resolve().parents[2] / "contracts" / "events"


def schemas() -> dict[str, dict]:
    return {p.name.split(".")[0]: json.loads(p.read_text()) for p in EVENTS.glob("*.schema.json")}


def check(event_type: str, payload: dict) -> None:
    """A light check without a JSON Schema library: required payload fields exist."""
    schema = schemas().get(event_type)
    if schema is None:
        pytest.fail(f"no schema for {event_type} in contracts/events/")
    required = schema["properties"]["payload"]["required"]
    missing = [field for field in required if field not in payload]
    assert not missing, f"{event_type} payload is missing {missing}"


async def test_listing_published_matches_its_schema(api):
    from sqlalchemy import select

    from app.core.db import get_sessionmaker
    from app.core.models import OutboxEvent
    from tests.conftest import create_listing, lister

    owner = await lister(api)
    listing = await create_listing(owner)
    async with get_sessionmaker()() as session:
        event = await session.scalar(
            select(OutboxEvent).where(
                OutboxEvent.type == "ListingPublished", OutboxEvent.aggregate_id == listing["id"]
            )
        )
    assert event is not None and event.topic == "listings.events"
    check(event.type, event.payload)


async def test_booking_events_match_their_schemas(api):
    from sqlalchemy import select

    from app.core.db import get_sessionmaker
    from app.core.models import OutboxEvent
    from tests.conftest import approved_booking

    _, _, booking = await approved_booking(api)
    async with get_sessionmaker()() as session:
        events = list(
            await session.scalars(
                select(OutboxEvent).where(OutboxEvent.aggregate_id == booking["id"])
            )
        )
    assert {e.type for e in events} >= {"BookingRequested", "BookingDecided"}
    for event in events:
        check(event.type, event.payload)
