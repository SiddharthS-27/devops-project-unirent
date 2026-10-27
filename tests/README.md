# tests/

Owner: Parv

Cross-module suites that run against a running stack: real PostgreSQL, Redis, Kafka and MinIO, with `razorpay_sim/` standing in for Razorpay and sending signed webhooks. Unit tests live next to the code they test, in each owner's folder.

| Folder | What |
|---|---|
| `fixtures/` | The client (`User`, `sign_in`, `admin`, `internal`, `sim`) and data builders (`onboarded`, `owner`, `listing`, `upload`) |
| `integration/` | Behaviour that crosses packages: sign-in, listings, bookings, payments, webhooks |
| `e2e/` | Whole journeys: rental, overdue, return, sale, appeal |
| `security/` | Object-level authorization, privilege escalation, rate-limit bypass, data masking |
| `performance/` | Locust scenarios |
| `razorpay_sim/` | The Razorpay simulator (FastAPI); `/sim/*` routes let tests pay, fail and replay webhooks |

Every test creates its own users and listings with unique names, so tests don't depend on each other or on seed data.

## Run

```bash
make up PROFILE=test && make migrate && make seed
make test-integration      # in the test-runner container
# or from a laptop against the dev stack:
cd tests && pip install -r requirements.txt && pytest -q integration
```

Suites marked `payments`, `security`, `bookings` and `reconciliation` are the merge gate; CI names them when they fail.
