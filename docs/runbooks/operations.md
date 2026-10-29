# Operations runbook

Owner: Sasvat. Commands run on the staging host from `~/unirent` unless stated. `compose` means `docker compose -f infra/compose.yaml --env-file infra/env/.env --profile staging`.

## Deploys

CI deploys every push to `master` (`deploy` job) with `ci/scripts/deploy.sh <sha>`: pull the commit's images, migrate, restart, health check, roll back on failure.

- **Deploy by hand:** `ci/scripts/deploy.sh <sha>` (the images must already be in GHCR).
- **Roll back:** `ci/scripts/deploy.sh <previous sha>`. Migrations only add things, so the previous api runs on the newer schema.
- **Health:** `ci/scripts/health-check.sh https://$STAGING_DOMAIN` (needs `SMOKE_STAFF_EMAIL` and `SMOKE_STAFF_PASSWORD`).

## Alerts

| Alert | First look | Usual fix |
|---|---|---|
| `ApiLatencyHigh` | API dashboard, slowest routes; Infrastructure → database connections | Restart the api if the pool is exhausted; find the query in Loki by `route` |
| `PaymentSuccessLow` | Payments dashboard; Razorpay status page; api logs for `razorpay error` | Usually Razorpay or the bank; tell students to pay cash meanwhile |
| `ConsumerLagHigh` | Events dashboard; `compose logs workers` | Restart workers; check Kafka health |
| `DeadLetter` | `compose exec workers python -m unirent_workers.replay --list` | Fix the cause, then replay (below) |
| `ReconciliationMismatch` | Admin app → Reconciliation report | See below |
| `ContainerDown` | `compose ps`; the container's logs | `compose up -d <service>` |
| `OutboxBacklog` | Kafka health; relay logs | Events are safe in the outbox; they publish once Kafka is back |

## Dead letters

An event that fails three in-process tries and one delayed retry is dead-lettered: it goes to `<topic>.dlq` and `workers.dead_letters`.

```bash
compose exec workers python -m unirent_workers.replay --list    # id, consumer, topic, type, error
compose exec workers python -m unirent_workers.replay 12 15     # after fixing the cause
compose exec workers python -m unirent_workers.replay --all
```

Replaying clears that consumer's processed mark for the event, so it is handled exactly once more.

## Kafka is down

Nothing the students do depends on Kafka: requests, payments and handovers keep working, and events wait in the outbox tables. Only pushes and saved-search alerts are late.

1. `compose ps kafka`; `compose logs --tail 100 kafka`.
2. `compose up -d kafka`, then watch `unirent_outbox_backlog` fall to 0 on the Events dashboard.
3. No replay is needed: the relay publishes the backlog in order.

## Reconciliation mismatch

1. Open the report (admin app → Reconciliation, or `GET /api/v1/admin/reconciliation/runs/<id>`).
2. By kind:
   - `missing_in_ledger`: Razorpay captured a payment we never recorded (for example a webhook that never arrived and no verify). Find the order in the api logs and replay its webhook from the Razorpay dashboard; the handler is idempotent.
   - `missing_in_razorpay` or `status_differs`: compare with the Razorpay dashboard. Never edit the ledger; corrections are new entries through a refund or ruling.
   - `amount_differs`, `transfer_missing`: check the order's transfer in the Razorpay dashboard; escalate to Siddharth.
3. Run again from the admin app to confirm zero mismatches.

## Demo clock (staging only)

`POST /api/v1/admin/clock {"offset_minutes": N}` moves the api's clock forward; the timer runner fires anything now due within 30 seconds. Reset with `{"offset_minutes": 0}` after the demo. The offset survives a restart.
