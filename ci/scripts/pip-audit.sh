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
  # The venv's own pip is audited too, so start from the current release.
  "/tmp/audit-$pkg/bin/pip" install -q --upgrade pip
  "/tmp/audit-$pkg/bin/pip" install -q -e "$root/security" >/dev/null 2>&1 || true
  [ -f "$root/payments/pyproject.toml" ] && "/tmp/audit-$pkg/bin/pip" install -q -e "$root/payments" >/dev/null 2>&1 || true
  "/tmp/audit-$pkg/bin/pip" install -q -e "$root/$pkg"
  # pip-audit audits its own environment unless pointed at another one's site-packages.
  site="$("/tmp/audit-$pkg/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
  pip-audit --path "$site" --skip-editable --progress-spinner off || status=1
done
exit $status
