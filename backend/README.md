# Backend

The UniRent API: one FastAPI process. It mounts the core modules in `app/modules/` and, from the `security/` and `payments/` packages, the sign-in and payment routers.

```
app/
  main.py          create_app(): middleware, error handlers, routers
  core/            config, database, outbox and timer writers, clock, errors
  modules/<name>/  router.py, service.py, models.py, schemas.py
migrations/        Alembic, `core` schema only
tests/
```

## Run locally

The easiest way is the Compose stack (`make up` from the repo root). To run the API on the host against it:

```bash
python -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
export UNIRENT_DATABASE_URL=postgresql+asyncpg://unirent:unirent-dev-password@localhost:5432/unirent
alembic upgrade head
uvicorn app.main:app --reload
```

## Checks

```bash
ruff check . && ruff format --check .
pytest
```

Tests that need PostgreSQL and Redis use `UNIRENT_DATABASE_URL` and `UNIRENT_REDIS_URL`, and are skipped when the database is unreachable.
