"""Replay dead-lettered events once the cause is fixed.

    python -m unirent_workers.replay --list
    python -m unirent_workers.replay 12 15        # by dead_letters id
    python -m unirent_workers.replay --all

Each event is republished to its original topic and its processed mark for that
consumer is cleared, so the consumer handles it again; the dead_letters row is
then marked replayed. Run it in the workers container."""

import argparse
import asyncio
import sys
from datetime import UTC, datetime

from sqlalchemy import delete, select

from unirent_workers import db
from unirent_workers.kafka import encode, start_producer
from unirent_workers.models import DeadLetter, ProcessedEvent


async def pending() -> list[DeadLetter]:
    async with db.sessionmaker()() as session:
        rows = await session.scalars(
            select(DeadLetter).where(DeadLetter.replayed_at.is_(None)).order_by(DeadLetter.id)
        )
        return list(rows)


async def replay(ids: list[int] | None) -> int:
    producer = await start_producer()
    count = 0
    try:
        async with db.sessionmaker()() as session:
            stmt = select(DeadLetter).where(DeadLetter.replayed_at.is_(None))
            if ids:
                stmt = stmt.where(DeadLetter.id.in_(ids))
            for letter in await session.scalars(stmt.order_by(DeadLetter.id)):
                if letter.event_id is not None:
                    await session.execute(
                        delete(ProcessedEvent).where(
                            ProcessedEvent.consumer == letter.consumer,
                            ProcessedEvent.event_id == letter.event_id,
                        )
                    )
                key = str(letter.payload.get("aggregate_id", "")).encode() or None
                await producer.send_and_wait(letter.topic, encode(letter.payload), key=key)
                letter.replayed_at = datetime.now(UTC)
                count += 1
            await session.commit()
    finally:
        await producer.stop()
        await db.dispose()
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("ids", nargs="*", type=int)
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    if args.list:
        for letter in asyncio.run(pending()):
            print(letter.id, letter.consumer, letter.topic, letter.type, letter.error[:80])
        return 0
    if not args.ids and not args.all:
        parser.error("give dead-letter ids, or --all")
    print(f"replayed {asyncio.run(replay(args.ids or None))} events")
    return 0


if __name__ == "__main__":
    sys.exit(main())
