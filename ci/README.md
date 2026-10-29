# ci/

Owner: Sasvat. The pipeline is GitHub Actions (`.github/workflows/ci.yml`); this folder holds the scripts its jobs call, so each stage can also be run on a laptop.

| Stage | Job | Script | Fails when |
|---|---|---|---|
| 1. Changes | `changes` | | n/a |
| 2. Lint | `lint-python`, `lint-flutter` | | Any ruff, `dart format` or `flutter analyze` finding |
| 3. Unit tests | `unit-python`, `unit-flutter` | `scripts/python-unit.sh <folder>` | Any failure |
| 4. Integration | `integration` | `scripts/integration.sh` | Any failure in `tests/integration` or `tests/e2e` |
| 5. Security scan | `scan`, Trivy in `images` | `scripts/pip-audit.sh` | A known vulnerability, a committed secret, or a high or critical image finding |
| 6. Contract check | `contract` | `scripts/contract-check.sh` | `contracts/openapi.json` is stale (runs when `backend/` or `contracts/` change; a stale app client is only a warning) |
| 7. Build and push | `images` | | Build error. Pushes `ghcr.io/<owner>/unirent-{api,workers}:<sha>` from master |
| 8. Deploy (master only) | `deploy` | `scripts/deploy.sh <sha>` on the staging host | Pull, migrate or restart error |
| 9. Health check | `deploy` | `scripts/health-check.sh <url>` | `/healthz`, `/readyz`, staff login or search fails; the previous tag is restored |

Branch protection requires only `ci-ok`, which fails if any stage failed.

The deploy job needs these repository secrets: `STAGING_HOST`, `STAGING_USER`, `STAGING_SSH_KEY`, `SMOKE_STAFF_EMAIL`, `SMOKE_STAFF_PASSWORD`. The staging host has the repo at `~/unirent`, Docker logged in to GHCR, and `infra/env/.env` filled in with `ENVIRONMENT=staging`.
