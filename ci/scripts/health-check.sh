#!/usr/bin/env bash
# After a deploy: liveness, readiness, then a smoke test of staff login and
# listing search. Usage: health-check.sh <base url>
set -euo pipefail
base="${1:-http://localhost:8000}"

for attempt in $(seq 1 20); do
  if curl -fsS "$base/healthz" > /dev/null && curl -fsS "$base/readyz" > /dev/null; then
    break
  fi
  [ "$attempt" -eq 20 ] && { echo "api not ready" >&2; exit 1; }
  sleep 3
done

token=$(curl -fsS -X POST "$base/api/v1/auth/staff/login" -H 'content-type: application/json' \
  -d "{\"email\": \"$SMOKE_STAFF_EMAIL\", \"password\": \"$SMOKE_STAFF_PASSWORD\"}" \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])')
curl -fsS "$base/api/v1/search?q=camera&limit=1" -H "authorization: Bearer $token" > /dev/null
echo "healthy"
