# contracts/

Shared. Whoever produces an API or event edits its file; whoever consumes it reviews the change.

- `openapi.json`: exported by CI from the running API.
- `events/<EventName>.schema.json`: one JSON Schema per event. Every event uses the envelope `event_id`, `type`, `version`, `occurred_at`, `producer`, `aggregate_id`, `payload`.
