#!/usr/bin/env bash
# Contract check: the committed OpenAPI spec must match what the backend produces.
# The app's owner regenerates its client, so a client behind the spec is a warning.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root/backend"
python -m app.export_openapi --check ../contracts/openapi.json
if [ -f "$root/frontend/tool/generate_api.dart" ] && command -v dart > /dev/null; then
  cd "$root/frontend"
  dart run tool/generate_api.dart --check ||
    echo "::warning::frontend/lib/api/generated is behind contracts/openapi.json; run dart run tool/generate_api.dart"
fi
