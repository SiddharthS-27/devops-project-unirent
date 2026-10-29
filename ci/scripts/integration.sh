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
# Test settings: presigned photo URLs must work inside the network, and every
# test student signs in from the one test-runner container.
export STORAGE_PUBLIC_URL=http://minio:9000
export SIGNIN_LIMIT_PER_MINUTE=100000
mkdir -p test-results
# The test-runner image writes its JUnit files as its own user (uid 10001).
chmod a+rwx test-results
compose=(docker compose -f infra/compose.yaml --env-file infra/env/.env --profile test)
trap '"${compose[@]}" logs --no-color api > integration-api.log 2>&1 || true; "${compose[@]}" down -v' EXIT

"${compose[@]}" up -d --build --wait
# The photos bucket, as make up creates it (minio-init is a one-shot in its own profile).
"${compose[@]}" run --rm minio-init
"${compose[@]}" exec -T api sh /src/infra/scripts/migrate.sh
"${compose[@]}" exec -T api python /src/infra/seed/seed.py
failed=()
for suite in "${suites[@]}"; do
  "${compose[@]}" --profile runner run --rm test-runner pytest -q "$suite" --junitxml="/results/$suite.xml" \
    || failed+=("$suite")
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "failed suites: ${failed[*]}"
  exit 1
fi
