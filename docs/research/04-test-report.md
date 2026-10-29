# Final test report

The full regression run for the demo (plan W8), at the build tip on 29 Oct 2026. Every suite ran against the dev Compose stack on one laptop: real Postgres, Redis, Kafka and MinIO, with the Razorpay simulator sending signed webhooks. Microsoft sign-in and phone OTP ran in mock mode, and push ran in log mode.

## Results

| Suite | Where | Tests | Result |
|---|---|---|---|
| Security package unit | `security/tests` | 59 | pass |
| Payments package unit | `payments/tests` | 57 | pass |
| Backend unit | `backend/tests` | 125 | pass |
| Workers unit | `workers/tests` | 42 | pass |
| Integration | `tests/integration` | 24 | pass |
| End to end | `tests/e2e` | 5 | pass |
| Security | `tests/security` | 48 | pass |
| Resilience | `tests/resilience` | 4 | pass |
| App (Flutter) | `frontend/test` | 376 | pass |
| **Total** | | **740** | **all pass** |

Some unit tests need a running stack and skip without one:

- `security/tests/test_every_endpoint.py` needs `UNIRENT_API_URL`.
- The workers database tests need `UNIRENT_WORKERS_DATABASE_URL`.

Both were set for this run, so the counts above include those tests.

## Every test from the PPT

| PPT test | Where | Covered by |
|---|---|---|
| Duplicate payment request creates one effect | integration | `test_payment_safety.py`: same key sent sequentially and concurrently; a key reused for a different request is refused |
| Concurrent reservation of the same asset | integration | `test_concurrent_approvals_of_overlapping_requests_one_wins` (Postgres exclusion constraint) |
| Full payment and rental lifecycle | e2e | `test_rental_journey.py`: UPI with an extension and a damage charge; cash returned without charges |
| Webhook retry and signature verification | integration, resilience | Replays, bad signatures, a webhook before verify; `test_delayed_settlement.py` storm of duplicate deliveries |
| Payout release and partial release | integration, e2e | Transfers to linked accounts at capture; partial refund after a ruling in `test_demo_path.py` |
| Broken object-level authorization | security | `test_object_level_auth.py`: every ID-taking endpoint called with another student's IDs |
| Privilege escalation on admin and settlement APIs | security | `test_privilege_escalation.py`; `test_every_endpoint.py` checks every route in the spec refuses the wrong role |
| Rate-limit bypass on auth and payment routes | security | `test_rate_limit_bypass.py`: spoofed forwarding headers, token rotation, parallel clients |
| Serial numbers masked in public listing APIs | security | `test_masking.py` scans every public response for full serials and residence data |
| Dependency and secret scanning | CI | `scan` job: Gitleaks and pip-audit; Trivy scans each image in the `images` job |
| Burst notification fan-out | performance | `ListingPublisher` in the Locust run (below) |
| Payment retry storms | performance | `PaymentRetryStorm`: the same key resent, method switches, webhook replays |
| Kafka consumer lag under load | performance | Lag read from Prometheus during the Locust run (below) |
| Database contention on hot listings | performance | `HotListingCrowd`: everyone requests one listing, and the owner approves |
| Delayed settlement processing | resilience | `test_delayed_settlement.py`: a late webhook alone captures; a missing webhook is covered by verify; a transfer before capture is harmless |
| State transitions, idempotency, ledger maths, trust | unit | `backend/tests` (state machine, trust), `payments/tests` (idempotency, ledger, late fees) |

The extra e2e flows the plan asked for:

| Flow | Covered by |
|---|---|
| Sale flow | `test_a_sale_moves_the_item_and_both_review_blind` |
| Cancellation with a note and the rating that follows | `test_cancellation_note_rating_and_public_count` |
| Extension | `test_rental_from_request_to_reviews_with_extension_damage_and_upi` |
| Overdue with late fees, on the staging clock | `test_demo_path.py` |
| Appeal, ruling and admin overrule | `test_demo_path.py` |
| Blind reviews | both e2e files |
| The 24-hour review release | `backend/tests/test_reviews.py` with a moved clock, not e2e |
| Reconciliation showing zero mismatches | `test_demo_path.py` |

## Performance (Locust)

```bash
locust -f performance/locustfile.py --host http://localhost:8000 --headless -u 50 -r 10 -t 120s
```

The run used 50 students, ramped at 10 a second, for 2 minutes. They split by weight: 30 browsing and typing ahead, 10 crowding one hot listing, 5 in payment retry storms and 5 publishing listings that match saved searches.

| Route | Requests | Failures | p50 ms | p95 ms | p99 ms |
|---|---|---|---|---|---|
| `GET /search/suggest` | 3,339 | 0 | 26 | 140 | 240 |
| `GET /search` | 514 | 0 | 40 | 310 | 380 |
| `GET /home` | 315 | 0 | 30 | 340 | 430 |
| `GET /listings/{id}` (hot listing) | 355 | 0 | 57 | 640 | 790 |
| `POST /bookings` (hot listing) | 864 | 0 | 34 | 440 | 610 |
| `POST …/pickup/payment` (same key) | 314 | 0 | 4 | 30 | 83 |
| **All** | **5,761** | **0** | **28** | **260** | **500** |

- **Throughput:** 48 requests a second, with no errors.
- **Latency:** every route stayed under the `ApiLatencyHigh` alert's 1-second p95. The slowest request took 1.7 s: a booking request on the hot listing while ten students raced for it.
- **Contention:** the exclusion constraint never let two overlapping bookings through, and the losers got `409 SLOT_TAKEN`.
- **Retry storm:** a resent payment start with the same key was replayed from the idempotency store in single-digit milliseconds.
- **Kafka lag:** the push and matcher consumers peaked at 24 and 22 messages behind during the run. Peak lag stayed in the tens, so fan-out kept pace with the publishers.

The first run failed 4.5% of requests with `429`. Each simulated student fired a suggestion on every keystroke with no gap, which hit the 120-a-minute per-account limit. The app waits 250 ms after the last key, so the scenario now models a 300 ms-a-key typist, the worst case the app can produce (`fix(tests): pace type-ahead load like the app's debounce`).

## Resilience

The full method and numbers are in [docs/runbooks/resilience.md](../runbooks/resilience.md).

| Experiment | Result |
|---|---|
| Kafka stopped for 5 minutes under traffic | The app kept working; the outbox drained 0.2 s after Kafka returned; no event lost or handled twice; ledger balanced |
| Workers killed mid-burst | Restarted from committed offsets; 12/12 push events handled once |
| Workers paused (consumers fall behind) | Backlog of 12 cleared on resume; 9/9 handled once |

## Bugs found during the run

| Found by | Bug | Fix |
|---|---|---|
| Backend unit run on a full database | The moderators' flagged-users list came from a set, so paging could skip or repeat students | `fix(backend): keep the flagged-users list in a stable order` |
| App appeal screens | A sale in appeal made the booking view return 500 (no Charges step in a sale) | `fix(backend): show a sale in appeal at the Reviews step` |
| Locust run, consumer lag check | Leftover test consumer groups would fire `ConsumerLagHigh` | `fix(monitoring): alert on lag of the app's consumer groups only` |
| App accessibility pass | Date pickers, the photo tile and an item card couldn't be activated by a screen reader; overflow on 360-pixel phones and at 2× text | `fix(frontend): fix accessibility and polish issues` |

## Not covered

- **Real third parties:** Microsoft Entra, Firebase phone auth, Razorpay and FCM ran as mocks or the simulator. The staging host with real test-mode keys is the place to try them, before the demo.
- **iOS:** the app was tested on Android and in widget tests only.
