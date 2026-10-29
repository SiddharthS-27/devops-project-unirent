import pytest

from fixtures.client import raw


def pytest_sessionstart(session):
    """Fail fast with a clear message when the stack isn't up."""
    try:
        with raw() as http:
            ready = http.get("/readyz")
    except Exception as exc:  # noqa: BLE001
        pytest.exit(f"the api is not reachable: {exc}. Start it with `make up`.", returncode=3)
    if ready.status_code != 200:
        pytest.exit(f"the api is not ready: {ready.text}", returncode=3)
