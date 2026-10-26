# infra/

Owner: Parv

- `compose.yaml`: every service. Services without a profile run in all profiles; `dev`, `test` and `staging` profiles are added as services land.
- `env/.env.example`: every variable and its owner. Copy to `env/.env` (`make up` does this).
- `postgres/init.sql`: creates the per-owner schemas and `pg_trgm`.
- Coming next: `docker/` (api, workers and tests Dockerfiles) and `seed/` (demo users, listings and bookings).
