from prometheus_client import Counter, Gauge

PAYMENTS = Counter("unirent_payments_total", "Payment outcomes", ["method", "outcome"])
RECONCILIATION_MISMATCHES = Gauge(
    "unirent_reconciliation_mismatches", "Mismatches found by the latest reconciliation run"
)
