# security/

Owner: Siddharth

Python package `unirent_security`, installed into the api process. It answers two questions for every other module: who is calling, and what may they do.

| Module | What it does |
|---|---|
| `microsoft` | Verifies Microsoft ID tokens: signature, audience, issuer, tenant and email domain |
| `staff_auth` | Staff email and password login (Argon2id), lockout, moderator accounts |
| `tokens` | 15-minute access JWTs; 30-day refresh tokens, rotated on use, with reuse detection |
| `phone_otp` | Verifies Firebase phone ID tokens and saves the verified number |
| `roles` | `current_account`, `require_role(...)`, `require_active` FastAPI dependencies |
| `ownership` | `require_owner(...)` for object-level checks |
| `accounts` | Account lookups and `set_account_status(...)` |
| `rate_limit` | Redis sliding-window limits |
| `audit` | `audit.record(...)` into the append-only audit log |
| `masking` | `mask_serial(...)` |
| `api` | The `/auth` and `/admin/moderators` routers |

Migrations for the `security` schema are in `migrations/` (`alembic upgrade head`).

## Development modes

Without real Microsoft or Firebase projects, set `UNIRENT_MS_AUTH_MODE=mock` and `UNIRENT_PHONE_AUTH_MODE=mock`. The mock token endpoints (`POST /api/v1/auth/microsoft/mock-token`, `POST /api/v1/auth/phone/mock-token`) then issue signed test tokens. Both modes are refused in staging and production.

## Checks

```bash
pip install -e ".[dev]"
ruff check . && ruff format --check .
pytest   # uses UNIRENT_DATABASE_URL and UNIRENT_REDIS_URL; database tests skip if unreachable
```
