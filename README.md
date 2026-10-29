# UniRent

Campus rental and resale app for one university. Verified students lend, rent, buy and sell with each other; every request, handover, payment and review is recorded and turned into a public trust score.

- **App:** Flutter (Android first), in `frontend/`.
- **API:** one FastAPI process (modular monolith) in `backend/`, with the `security/` and `payments/` Python packages installed into it.
- **Data and events:** PostgreSQL 16 (one schema per owner), Redis 7, Kafka (KRaft) through an outbox, MinIO for photos.
- **Workers:** outbox relay, push sender, timer runner, saved-search matcher, nightly reconciliation, in `workers/`.
- **CI:** GitHub Actions (`.github/workflows/`), with shared scripts in `ci/`.

The plans live in `docs/plans/`: the product plan decides what the app does, the implementation plan decides how.

## Quick start

Requires Docker with Compose v2 and GNU make.

```bash
make up        # dev profile: databases, api, workers, simulators; waits until healthy
make migrate   # run every package's migrations
make seed      # demo accounts, listings and bookings
make logs      # follow logs
make down      # stop everything
make reset     # stop and delete all volumes
```

`make up` copies `infra/env/.env.example` to `infra/env/.env` on first run. Put real secrets (Razorpay, Microsoft, Firebase) only in `infra/env/.env`, which is never committed. Without them the stack runs against the Razorpay simulator and mock sign-in.

Compose profiles: `dev` (default for `make up`), `test` (CI and `make test-integration`), `staging`, `monitoring` (`make monitoring`) and `tunnel` (`make tunnel`).

Host ports:

| Service | Port |
|---|---|
| API | 8000 |
| PostgreSQL | 5432 (`POSTGRES_PORT`) |
| Redis | 6379 (`REDIS_PORT`) |
| Kafka (from the host) | 29092 |
| MinIO API / console | 9000 / 9001 |
| Kafka UI (dev) | 8080 |
| Razorpay simulator | 8090 |
| Grafana / Prometheus / Alertmanager | 3000 / 9090 / 9093 |

## Tests

```bash
make test-unit          # pytest in each Python package
make test-integration   # tests/integration against the test profile
make test-e2e           # tests/e2e
make test-security      # tests/security
make test-resilience    # tests/resilience: delayed and duplicate settlement
make test-load          # Locust scenarios in tests/performance
make resilience         # Kafka and worker failure experiments on the running stack
```

The app: `cd frontend && flutter test`. The latest full run, with load and resilience numbers, is in [docs/research/04-test-report.md](docs/research/04-test-report.md); operating the stack is covered in [docs/runbooks/](docs/runbooks/).

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
| `docs/` | Shared | Plans, research notes, runbooks |

`.github/CODEOWNERS` lists who owns each folder.

## Branching

1. `master` is protected and always deployable; staging deploys from it.
2. Branch names follow `<name>/<topic>`, for example `parv/compose-environment` or `siddharth/payments-core`.
3. Change only folders you own. For anything else, open an issue or a small PR for the owner to review.
4. A PR merges when CI passes and one teammate other than the author approves. Merge with "Rebase and merge", never squash.
5. Rebase on `master` daily and keep PRs under about 400 changed lines.
6. Commit messages follow Conventional Commits: `type(scope): summary`, where the scope is the folder name.
7. Commit with `git config user.email` set to your GitHub noreply address, so the commits are credited to you.
