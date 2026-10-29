# payments/

Owner: Siddharth

Python package `unirent_payments`, installed into the api process. Every rupee that moves goes through it, and it keeps the proof that each moved exactly once.

| Module | What it does |
|---|---|
| `razorpay_client` | Async client for the parts of the Razorpay API we use |
| `linked_accounts` | Route linked accounts for owners and sellers; `payout_ready()` |
| `payments` | `start_payment()`, `mark_cash_paid()`, `payment_status()`; the payment state machine |
| `idempotency` | `Idempotency-Key` replay for every money and booking request |
| `ledger` | Append-only double-entry ledger |
| `webhooks` | Signed Razorpay webhooks and checkout verification |
| `late_fees` | Versioned late-fee rule and calculator |
| `refunds` | Refunds with transfer reversal; cash refunds |
| `reconciliation` | Ledger against Razorpay payments, transfers and settlements |
| `api` | The FastAPI router the backend mounts under `/api/v1` |

Money is always an integer number of paise. Migrations for the `payments` schema are in `migrations/`.

## Without Razorpay keys

Point `UNIRENT_RAZORPAY_API_BASE` at the simulator in `tests/razorpay_sim/` (the dev and test Compose profiles do this). It implements the endpoints above and sends signed webhooks.

## Checks

```bash
pip install -e ../security -e ".[dev]"
ruff check . && ruff format --check .
pytest   # database tests use UNIRENT_DATABASE_URL and skip if it is unreachable
```
