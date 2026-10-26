# UniRent

Campus rental and resale app for students. Flutter mobile app, FastAPI modular monolith, PostgreSQL, Redis, Kafka and MinIO.

## Quick start

Requires Docker with Compose v2.

```bash
make up      # starts postgres, redis, kafka and minio, waits until healthy
make logs    # follow logs
make down    # stop everything
make reset   # stop and delete all volumes
```

`make up` copies `infra/env/.env.example` to `infra/env/.env` on first run. Put real secrets only in `infra/env/.env`, which is never committed.

Host ports:

| Service | Port |
|---|---|
| PostgreSQL | 5432 (`POSTGRES_PORT`) |
| Redis | 6379 (`REDIS_PORT`) |
| Kafka (from the host) | 29092 |
| MinIO API / console | 9000 / 9001 |

## Folders and owners

| Folder | Owner | Contents |
|---|---|---|
| `frontend/` | Sripranav | Flutter app: student, moderator and admin screens |
| `backend/` | Rammohan | FastAPI app, core modules, help chatbot |
| `payments/` | Siddharth | Razorpay, ledger, late fees, refunds, reconciliation |
| `security/` | Siddharth | Sign-in, tokens, roles, ownership checks, rate limits, audit log |
| `workers/` | Sasvat | Outbox relay, Kafka consumers, timer runner, push sender |
| `ci/`, `.github/workflows/` | Sasvat | GitHub Actions workflows and pipeline scripts |
| `monitoring/` | Sasvat | Prometheus, Alertmanager, Grafana and Loki configs |
| `infra/` | Parv | Compose file, Dockerfiles, env templates, seed data |
| `tests/` | Parv | Integration, end-to-end, security and performance suites |
| `contracts/` | Shared | OpenAPI spec and event schemas |
| `docs/` | Shared | Plans, decision records, runbooks, research |

`.github/CODEOWNERS` enforces this ownership on pull requests.

## Branching

1. `main` is protected and always deployable.
2. Branch names follow `<type>/<topic>`, for example `feat/compose-kafka` or `fix/otp-expiry`. Types: `feat`, `fix`, `chore`, `docs`, `test`, `ci`.
3. Change only folders you own. For anything else, open an issue or a small PR for the owner to review.
4. A PR merges when CI passes and the code owner of every touched folder approves.
5. Rebase on `main` daily and keep PRs under about 400 changed lines.
6. Commit from your own machine with `git config user.email` set to an email verified on your GitHub account, so the commits are credited to you.
