#!/usr/bin/env bash
# Audit each Python package's resolved dependencies for known vulnerabilities.
# The local packages themselves aren't on PyPI, so they are skipped.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
pip install -q pip-audit
status=0
for pkg in security payments backend workers; do
  [ -f "$root/$pkg/pyproject.toml" ] || continue
  echo "== $pkg"
  python -m venv "/tmp/audit-$pkg"
  "/tmp/audit-$pkg/bin/pip" install -q -e "$root/security" >/dev/null 2>&1 || true
  [ -f "$root/payments/pyproject.toml" ] && "/tmp/audit-$pkg/bin/pip" install -q -e "$root/payments" >/dev/null 2>&1 || true
  "/tmp/audit-$pkg/bin/pip" install -q -e "$root/$pkg"
  pip-audit --python "/tmp/audit-$pkg/bin/python" --skip-editable --progress-spinner off || status=1
done
exit $status
