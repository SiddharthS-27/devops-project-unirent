# infra/

Owner: Parv

Everything needed to run UniRent with one command: `make up && make migrate && make seed`.

| Path | What |
|---|---|
| `compose.yaml` | Every service, by profile (below) |
| `docker/` | Dockerfiles for the api, the workers and the tests image (test-runner and Razorpay simulator), each with its own `.dockerignore` |
| `postgres/` | First-start scripts: the four schemas, `pg_trgm` and `btree_gist`, and the restricted app and workers users |
| `scripts/` | `migrate.sh` (every package's Alembic history, in dependency order) and `create-topics.sh` (from `workers/topics.yaml`) |
| `seed/seed.py` | Demo data: admin, 2 moderators, 10 students, 20 listings, a booking in every state |
| `caddy/` | Staging's HTTPS front door |
| `env/.env.example` | Every variable with its owner; copied to `env/.env` on first `make up` |
| `env/staging.env.example` | The staging host's settings |

## Profiles

| Profile | Runs |
|---|---|
| (always) | PostgreSQL, Redis, Kafka, MinIO |
| `dev` | api (hot reload with `make watch`), workers, Razorpay simulator, kafka-ui |
| `test` | api, workers, Razorpay simulator; `runner` adds the test-runner (`make test-*`, CI) |
| `staging` | api and workers from GHCR images, Caddy, and the monitoring stack |
| `monitoring` | Prometheus, Alertmanager, Grafana, Loki, Promtail and exporters, in dev |
| `tunnel` | A cloudflared quick tunnel for Razorpay webhooks to a laptop (`make tunnel`) |

## Accounts after `make seed`

Students sign in with mock Microsoft sign-in using their email (`asha@college.edu`, `ravi@college.edu`, … see `seed/seed.py`); the phone code is `123456`. Staff: `ADMIN_EMAIL` / `ADMIN_PASSWORD` from `.env`, and `mod1@unirent.in`, `mod2@unirent.in` with `moderator-pass-1` (changed on first login).

Real Microsoft, Firebase and Razorpay credentials go only in `env/.env`; without them the stack runs on the mocks and the simulator.
