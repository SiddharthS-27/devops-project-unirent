# Razorpay Route in test mode

Status: findings from Razorpay's documentation and the test dashboard. Each item lists what the code relies on and the fallback if test mode doesn't behave as documented.

## Linked accounts

- Route must be **enabled on the account** (a request through the dashboard; activation is usually quick in test mode).
- A linked account is created with the Accounts API v2 (`POST /v2/accounts`, `type: route`), then a stakeholder, then a product configuration for `route` that carries the settlement bank account (`account_number`, `ifsc_code`, `beneficiary_name`).
- The product configuration reports `activation_status`. In test mode, accounts move to `activated` without manual review.
- We store only the linked account ID (`acc_...`) and its status. Bank details pass through the backend to Razorpay and are never stored or logged.

## Orders with transfers

- `POST /v1/orders` accepts a `transfers` array: `{account, amount, currency: "INR"}`. The transfer is created automatically when the payment is captured.
- Amounts are in paise, which matches our API convention.
- Checkout success returns `razorpay_payment_id`, `razorpay_order_id` and `razorpay_signature`. The signature is `HMAC_SHA256(order_id + "|" + payment_id, key_secret)`.

## Refunds with transfer reversal

- `POST /v1/payments/{id}/refund` with `reverse_all: 1` reverses the transfer from the linked account in the same call. Partial refunds pass `amount`.
- A reversal needs enough balance in the linked account. In test mode this is not enforced.

## Webhooks

- The signature header is `X-Razorpay-Signature`: `HMAC_SHA256(raw_body, webhook_secret)`, hex-encoded. It must be computed over the raw bytes, before JSON parsing.
- Events we subscribe to: `payment.captured`, `payment.failed`, `transfer.processed`, `refund.processed`.
- Razorpay retries failed deliveries and can deliver out of order, so handlers must be idempotent and must not assume ordering.
- Webhooks need a public HTTPS URL. On a laptop: a `cloudflared` quick tunnel (`infra` `tunnel` service), whose URL is then set in the test dashboard.

## Settlements in test mode

- Test mode does **not** produce real settlements, so the settlements API returns little or nothing.
- Reconciliation therefore compares the ledger with Razorpay **payments, transfers and refunds**, which test mode does return, and treats settlement data as optional. On staging with test keys, the settlement check is reported as "not available" rather than as a mismatch.

## Simulator

Because webhooks to laptops are awkward and CI has no Razorpay keys, `tests/razorpay_sim/` implements the subset of the API we call (orders, payments, refunds, transfers, accounts) and sends correctly signed webhooks. The backend points at it with `RAZORPAY_API_BASE`.
