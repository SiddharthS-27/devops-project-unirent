# Resilience experiments

Owner: Sasvat. The plan's week-8 list, run with `ci/scripts/resilience.py` against a running stack (dev or staging profile, images built from the commit under test).

```bash
python3 ci/scripts/resilience.py kafka workers delay   # all three, about 8 minutes
KAFKA_DOWN_SECONDS=60 python3 ci/scripts/resilience.py kafka
```

| Experiment | What it does |
|---|---|
| `kafka` | Stops Kafka for `KAFKA_DOWN_SECONDS` (default 300) while students list items, book, pay by UPI and hand over, then starts it again |
| `workers` | Kills the workers container 8 seconds into a burst of bookings and payments, then brings it back |
| `delay` | Pauses the workers so consumers fall behind while traffic continues, then unpauses them |

After each one the script checks that:

- every outbox row written during the experiment was published (`unsent` 0)
- every event on a push topic was handled exactly once by the push consumer
- nothing was dead-lettered
- the ledger still balances

The script exits non-zero if any check fails.

`tests/resilience/` covers the case the script can't: Razorpay settling a payment late, by webhook only, while the booking waits.

## Results (29 Oct 2026, dev stack, build tip)

| Experiment | Traffic during the fault | Drained after recovery | Events (push) | Handled once | Dead letters | Ledger |
|---|---|---|---|---|---|---|
| Kafka down 300 s | 3 listings, 3 UPI payments | 0.2 s | 15 (9) | 9 / 9 | 0 | balanced |
| Workers killed | 4 listings, 4 UPI payments | 0.2 s | 20 (12) | 12 / 12 | 0 | balanced |
| Workers paused | 3 listings, 3 UPI payments; backlog of 12 | 0.4 s | 15 (9) | 9 / 9 | 0 | balanced |

With Kafka down, the api kept answering: requests, payments and handovers all succeeded, and their events waited in the outbox. Once Kafka was back, the relay published the backlog in order on its next poll. With the workers killed, the relay and consumers restarted from their committed offsets, and `processed_events` stopped any push going out twice.

## What the runs taught us

No change was needed in the app, workers or payments. The fixes were to the experiment and the environment:

- **Measure a bounded window.** The staging clock (admin → clock) can date outbox rows in the future. The first run counted hundreds of those as "written during the experiment". The script now ignores rows dated more than a minute ahead.
- **Wait for the outbox again before counting.** Timers keep firing during the 60-second settle, so a row written just before the check is briefly unsent. The check now waits for the outbox to drain once more before it counts anything.
- **Rebuild images after a migration.** One run used a workers image older than the database's latest workers migration. When Kafka came back, the workers restarted and crash-looped on `Can't locate revision`, so most push events went unhandled. Deploys don't hit this, because `ci/scripts/deploy.sh` runs the commit's own images. Locally, rebuild before running the experiments.
- **Don't run the test suites against the same stack at the same time.** A test consumer's deliberately broken handler shows up as a dead letter in the experiment's window.

## If a check fails

| Check | Look at |
|---|---|
| `unsent` > 0 | `SELECT topic, attempts, last_error FROM core.outbox WHERE sent_at IS NULL` (and `payments.outbox`); relay logs |
| Handled fewer than written | `compose ps workers` (restarting?); `compose logs workers`; consumer lag on the Events dashboard |
| Dead letters | `compose exec workers python -m unirent_workers.replay --list`, then [operations.md](operations.md#dead-letters) |
| Ledger unbalanced | Stop: this is a payments bug. Run reconciliation and tell Siddharth |
