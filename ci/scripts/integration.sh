#!/usr/bin/env bash
# Integration stage: bring up the test profile, migrate, run tests/integration,
# e2e, security and resilience, always tear down. A failure names the suite and
# its merge-gate markers (payments, security, bookings, reconciliation).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

suites=()
for suite in integration e2e security resilience; do
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
  # Each suite starts with fresh rate-limit budgets: staff login allows five
  # attempts per account in 15 minutes, and every suite signs the admin in.
  "${compose[@]}" exec -T redis sh -c "redis-cli --scan --pattern 'rl:*' | xargs -r redis-cli del" > /dev/null
  "${compose[@]}" --profile runner run --rm test-runner pytest -q "$suite" \
    --junitxml="/results/$suite.xml" -o junit_family=xunit2 || failed+=("$suite")
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "failed suites: ${failed[*]}"
  # Name the merge-gate areas that failed, from the JUnit results.
  for gate in payments security bookings reconciliation; do
    if grep -l "<failure" test-results/*.xml 2>/dev/null | xargs -r grep -q "$gate"; then
      echo "merge gate failed: $gate"
    fi
  done
  exit 1
fi
