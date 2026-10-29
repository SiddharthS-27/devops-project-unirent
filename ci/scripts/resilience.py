#!/usr/bin/env python3
"""Resilience experiments on a running stack (the plan's week-8 list):

  kafka    stop Kafka while students keep using the app, then start it again
  workers  kill the workers container in the middle of a burst of events
  delay    pause the workers so consumers fall behind, then let them catch up

After each: every outbox event written during the experiment was published
(none lost), each was handled once per consumer (no push sent twice), and
the booking and payment flows kept working throughout (money unaffected).

  python3 ci/scripts/resilience.py kafka workers delay
Environment: KAFKA_DOWN_SECONDS (default 300), BASE_URL, SIM_URL.
"""

import json
import os
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests"))

from fixtures.data import approved_booking, listing, owner, pay_upi, pickup_photos  # noqa: E402

COMPOSE = [
    "docker",
    "compose",
    "-f",
    str(ROOT / "infra/compose.yaml"),
    "--env-file",
    str(ROOT / "infra/env/.env"),
    "--profile",
    os.environ.get("PROFILE", "dev"),
]
PUSH_TOPICS = ("bookings.events", "moderation.events", "payments.events")


def compose(*args: str) -> None:
    subprocess.run([*COMPOSE, *args], check=True, capture_output=True)


def sql(query: str) -> str:
    out = subprocess.run(
        [
            *COMPOSE,
            "exec",
            "-T",
            "postgres",
            "psql",
            "-U",
            os.environ.get("POSTGRES_USER", "unirent"),
            "-d",
            "unirent",
            "-tAc",
            query,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return out.stdout.strip()


def outbox_since(since: str, where: str = "TRUE") -> str:
    """Both outboxes' rows written since `since` (and not dated in the future by a
    staging clock jump), as one subquery."""
    rows = []
    for table in ("core.outbox", "payments.outbox"):
        rows.append(
            f"SELECT id, topic, sent_at FROM {table} "
            f"WHERE occurred_at >= '{since}' AND occurred_at <= now() + interval '1 minute'"
        )
    return f"(SELECT * FROM ({' UNION ALL '.join(rows)}) u WHERE {where}) e"


def unsent_since(since: str) -> int:
    return int(sql(f"SELECT count(*) FROM {outbox_since(since, 'sent_at IS NULL')}"))


def traffic(rounds: int) -> dict:
    """Students listing, booking and paying, as during normal use."""
    done = {"listings": 0, "payments": 0}
    lister = owner("Resilience Owner")
    for _ in range(rounds):
        listing(lister)
        done["listings"] += 1
        a, b, booking = approved_booking()
        pickup_photos(a, b, booking["id"])
        pay_upi(b, booking["id"])
        done["payments"] += 1
    return done


def wait_drained(since: str, timeout: int = 180) -> float:
    started = time.time()
    while time.time() - started < timeout:
        unsent = unsent_since(since)
        if unsent == 0:
            return time.time() - started
        time.sleep(2)
    raise SystemExit(f"outbox not drained after {timeout}s")


def check(since: str, settle: int = 60) -> dict:
    """No event lost, none handled twice, every push-topic event handled once."""
    time.sleep(settle)  # let the consumers finish what the relay published
    wait_drained(since, timeout=30)  # a timer may have written a row just now
    events = sql(f"SELECT count(*) FROM {outbox_since(since)}")
    topics = ", ".join(repr(t) for t in PUSH_TOPICS)
    push_events = sql(
        f"SELECT string_agg(id::text, ',') FROM {outbox_since(since, f'topic IN ({topics})')}"
    )
    ids = [i for i in (push_events or "").split(",") if i]
    handled = (
        int(
            sql(
                "SELECT count(*) FROM workers.processed_events "
                f"WHERE consumer = 'push' AND event_id IN ({', '.join(repr(i) for i in ids)})"
            )
        )
        if ids
        else 0
    )
    unsent = unsent_since(since)
    dead = int(sql(f"SELECT count(*) FROM workers.dead_letters WHERE failed_at >= '{since}'"))
    ledger = sql(
        "SELECT sum(CASE WHEN direction = 'debit' THEN amount_paise ELSE 0 END) "
        "= sum(CASE WHEN direction = 'credit' THEN amount_paise ELSE 0 END) "
        "FROM payments.ledger_entries"
    )
    return {
        "events_written": int(events),
        "unsent": unsent,
        "push_events": len(ids),
        "push_events_handled": handled,
        "dead_letters": dead,
        "ledger_balanced": ledger == "t",
    }


def now() -> str:
    return datetime.now(UTC).isoformat()


def kafka() -> dict:
    down = int(os.environ.get("KAFKA_DOWN_SECONDS", "300"))
    since = now()
    compose("stop", "kafka")
    stopped = time.time()
    flows = traffic(3)  # the app keeps working with Kafka down
    time.sleep(max(0, down - (time.time() - stopped)))
    compose("start", "kafka")
    compose("up", "-d", "--wait", "kafka")
    drained = wait_drained(since)
    return {
        "kafka_down_seconds": down,
        "flows_during_outage": flows,
        "drained_after_seconds": round(drained, 1),
        **check(since),
    }


def workers() -> dict:
    since = now()
    proc = subprocess.Popen([sys.executable, __file__, "--traffic", "4"])
    time.sleep(8)
    compose("kill", "workers")
    time.sleep(10)
    proc.wait()
    compose("up", "-d", "--wait", "workers")
    drained = wait_drained(since)
    return {"drained_after_seconds": round(drained, 1), **check(since)}


def delay() -> dict:
    since = now()
    compose("pause", "workers")
    flows = traffic(3)
    time.sleep(60)
    backlog = int(
        sql(f"SELECT count(*) FROM core.outbox WHERE sent_at IS NULL AND occurred_at >= '{since}'")
    )
    compose("unpause", "workers")
    drained = wait_drained(since)
    return {
        "flows_while_paused": flows,
        "backlog_while_paused": backlog,
        "drained_after_seconds": round(drained, 1),
        **check(since),
    }


def main(argv: list[str]) -> int:
    if argv[:1] == ["--traffic"]:
        traffic(int(argv[1]))
        return 0
    results = {}
    for name in argv or ["kafka", "workers", "delay"]:
        print(f"== {name}", flush=True)
        results[name] = {"kafka": kafka, "workers": workers, "delay": delay}[name]()
        print(json.dumps(results[name], indent=2), flush=True)
    failed = [
        n
        for n, r in results.items()
        if r["unsent"] or r["push_events_handled"] != r["push_events"] or not r["ledger_balanced"]
    ]
    if failed:
        print(f"FAILED: {failed}")
        return 1
    print("all experiments passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
