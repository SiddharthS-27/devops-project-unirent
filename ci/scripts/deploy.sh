#!/usr/bin/env bash
# Deploy a commit's images to the staging host and roll back if it isn't healthy.
# Runs on the staging host (CI calls it over SSH):
#   deploy.sh <git sha>
# The host has the repo checked out at $STAGING_DIR with infra/env/.env filled in.
set -euo pipefail
sha="$1"
dir="${STAGING_DIR:-$HOME/unirent}"
registry="${REGISTRY:-ghcr.io/sasvat007}"
cd "$dir"

compose() { docker compose -f infra/compose.yaml --env-file infra/env/.env --profile staging "$@"; }
current_tag() { grep -s '^API_IMAGE=' infra/env/.env | sed 's/.*://' || true; }

previous="$(current_tag)"
echo "deploying $sha (previous: ${previous:-none})"

set_tag() {
  sed -i "s#^API_IMAGE=.*#API_IMAGE=$registry/unirent-api:$1#; s#^WORKERS_IMAGE=.*#WORKERS_IMAGE=$registry/unirent-workers:$1#" infra/env/.env
}

git fetch --quiet origin && git checkout --quiet "$sha"
set_tag "$sha"
compose pull api workers
compose up -d --wait --no-build api
compose exec -T api sh /src/infra/scripts/migrate.sh
compose up -d --wait --no-build

if ci/scripts/health-check.sh "${STAGING_URL:-http://localhost:8000}"; then
  echo "deployed $sha"
  exit 0
fi

echo "health check failed; rolling back to ${previous:-nothing}" >&2
if [ -n "$previous" ]; then
  git checkout --quiet "$previous"
  set_tag "$previous"
  compose up -d --wait --no-build
fi
exit 1
