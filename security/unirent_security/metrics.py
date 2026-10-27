from prometheus_client import Counter

AUTH_FAILURES = Counter("unirent_auth_failures_total", "Rejected sign-ins and tokens", ["reason"])
RATE_LIMITED = Counter("unirent_rate_limited_total", "Requests refused by a rate limit", ["route"])
