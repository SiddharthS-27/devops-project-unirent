# workers/

Owner: Sasvat

Python package `unirent_workers`, run as the `workers` container. Everything asynchronous lives here; nothing in it is on the path of a payment or a handover.

| Component | What it does |
|---|---|
| `relay` | Polls `core.outbox` and `payments.outbox`, publishes each event to its topic keyed by `aggregate_id`, marks it sent |
| `consumers/` | Kafka consumers with idempotent processing, retries with backoff, then `.retry` and `.dlq` |
| `consumers/push` | Maps events to recipients and messages; sends through FCM |
| `timers` | Every 30 seconds, fires due timers through the backend's internal API |
| `consumers/matcher` | On `ListingPublished`, pushes to students whose saved searches match |
| `reconciliation_trigger` | Starts payments reconciliation nightly at 02:00 IST |

`topics.yaml` lists the topics; the Compose `kafka-init` job creates them with their `.retry` and `.dlq` companions.

## Run

```bash
pip install -e ".[dev]"
unirent-workers            # every component
unirent-workers relay push # just these
```

`UNIRENT_PUSH_MODE=log` (the default) logs pushes instead of sending them; `fcm` sends through Firebase Cloud Messaging with the service account in `UNIRENT_FCM_CREDENTIALS_FILE`.

## Checks

```bash
ruff check . && ruff format --check .
pytest   # database tests use UNIRENT_WORKERS_DATABASE_URL and skip if it is unreachable
```
