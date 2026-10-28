from app.core.metrics import refresh_gauges


async def test_metrics_endpoint_serves_every_package(api):
    await api.get("/healthz")
    await refresh_gauges()
    body = (await api.get("/metrics/")).text
    for name in (
        "unirent_http_request_duration_seconds",
        "unirent_booking_transitions_total",
        "unirent_active_listings",
        "unirent_payments_total",
        "unirent_auth_failures_total",
        "unirent_rate_limited_total",
    ):
        assert name in body, name
    assert 'route="/healthz"' in body
