# Metric list

Every UniRent metric starts with `unirent_`. Owners add the metrics for their flows; the dashboards and alerts in this folder read them.

| Metric | Type | Labels | Added by | Where |
|---|---|---|---|---|
| `unirent_http_request_duration_seconds` | Histogram | route, method, status | Rammohan | `backend/app/core/metrics.py` |
| `unirent_booking_transitions_total` | Counter | from, to | Rammohan | booking state machine |
| `unirent_overdue_bookings` | Gauge | | Rammohan | refreshed every 30 s |
| `unirent_open_appeals` | Gauge | | Rammohan | refreshed every 30 s |
| `unirent_active_listings` | Gauge | | Rammohan | refreshed every 30 s |
| `unirent_bookings` | Gauge | state | Rammohan | refreshed every 30 s |
| `unirent_payments_total` | Counter | method, outcome | Siddharth | `payments/unirent_payments/metrics.py` |
| `unirent_reconciliation_mismatches` | Gauge | | Siddharth | set by each reconciliation run |
| `unirent_auth_failures_total` | Counter | reason | Siddharth | `security/unirent_security/metrics.py` |
| `unirent_rate_limited_total` | Counter | route | Siddharth | rate limiter |
| `unirent_events_relayed_total` | Counter | source | Sasvat | outbox relay |
| `unirent_outbox_backlog` | Gauge | source | Sasvat | outbox relay |
| `unirent_events_processed_total` | Counter | consumer, outcome | Sasvat | consumers |
| `unirent_event_retries_total` | Counter | consumer | Sasvat | consumers |
| `unirent_dlq_messages_total` | Counter | topic | Sasvat | consumers |
| `unirent_push_sent_total` | Counter | outcome | Sasvat | push sender |
| `unirent_timers_fired_total` | Counter | kind, outcome | Sasvat | timer runner |

Exporters add the infrastructure metrics: `pg_*` (postgres_exporter), `redis_*` (redis_exporter), `kafka_consumergroup_lag` (kafka-exporter), `container_*` (cAdvisor) and `node_*` (node_exporter).
