#!/usr/bin/env bash
# Lint-free half of the Python gate: install a package with its local
# dependencies, migrate a fresh database, run its unit tests.
# Usage: ci/scripts/python-unit.sh <folder>
# Needs UNIRENT_DATABASE_URL and UNIRENT_REDIS_URL pointing at empty services.
set -euo pipefail
folder="$1"
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

# The backend imports security and payments; payments imports security.
deps=()
case "$folder" in
  payments) deps=(security) ;;
  backend) deps=(security payments) ;;
esac

for pkg in "${deps[@]}" "$folder"; do
  if [ -f "$pkg/pyproject.toml" ]; then
    pip install -q -e "./$pkg[dev]"
  fi
done

# Prepare the database the way infra/postgres does, then migrate what the folder needs.
if [ -n "${PGHOST:-}" ]; then
  psql -v ON_ERROR_STOP=1 -q -f infra/postgres/01-schemas.sql
fi
for pkg in "${deps[@]}" "$folder"; do
  if [ -f "$pkg/alembic.ini" ]; then
    (cd "$pkg" && alembic upgrade head)
  fi
done

cd "$folder"
# Exit code 5 means no tests were collected, allowed until the folder has tests.
pytest -q --junitxml="$root/test-results-$folder.xml" || [ $? -eq 5 ]
