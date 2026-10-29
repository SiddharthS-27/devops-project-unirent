from prometheus_client import Counter, Gauge

EVENTS_RELAYED = Counter("unirent_events_relayed_total", "Outbox rows published", ["source"])
OUTBOX_BACKLOG = Gauge("unirent_outbox_backlog", "Unsent outbox rows", ["source"])
EVENTS_PROCESSED = Counter(
    "unirent_events_processed_total", "Events handled by consumers", ["consumer", "outcome"]
)
EVENT_RETRIES = Counter("unirent_event_retries_total", "In-process retries", ["consumer"])
DLQ_MESSAGES = Counter(
    "unirent_dlq_messages_total", "Events sent to a dead-letter topic", ["topic"]
)
PUSH_SENT = Counter("unirent_push_sent_total", "Push notifications", ["outcome"])
TIMERS_FIRED = Counter("unirent_timers_fired_total", "Timers fired", ["kind", "outcome"])
