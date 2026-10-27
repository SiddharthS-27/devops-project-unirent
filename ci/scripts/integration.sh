#!/usr/bin/env bash
# Integration stage: bring up the test profile, migrate, run tests/integration
# and tests/e2e, always tear down. Suites that don't exist yet are skipped.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

suites=()
for suite in integration e2e; do
  if compgen -G "tests/$suite/test_*.py" > /dev/null; then suites+=("$suite"); fi
done
if [ ${#suites[@]} -eq 0 ]; then
  echo "no integration suites yet; skipping"
  exit 0
fi

[ -f infra/env/.env ] || cp infra/env/.env.example infra/env/.env
compose=(docker compose -f infra/compose.yaml --env-file infra/env/.env --profile test)
trap '"${compose[@]}" logs --no-color api > integration-api.log 2>&1 || true; "${compose[@]}" down -v' EXIT

"${compose[@]}" up -d --build --wait
"${compose[@]}" exec -T api sh /src/infra/scripts/migrate.sh
for suite in "${suites[@]}"; do
  "${compose[@]}" run --rm test-runner pytest -q "$suite" --junitxml="/results/$suite.xml"
done
