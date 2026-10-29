from pathlib import Path

import pytest

from app.export_openapi import render

SPEC = Path(__file__).resolve().parents[2] / "contracts" / "openapi.json"


def test_every_route_is_versioned_or_internal():
    import json

    paths = json.loads(render())["paths"]
    for path in paths:
        assert path.startswith(("/api/v1/", "/internal/", "/healthz", "/readyz")), path


def test_booking_exposes_return_under_its_json_name():
    import json

    schemas = json.loads(render())["components"]["schemas"]
    booking = next(v for k, v in schemas.items() if k.startswith("BookingOut"))
    assert "return" in booking["properties"]


@pytest.mark.skipif(not SPEC.exists(), reason="contracts/openapi.json not exported yet")
def test_committed_spec_is_current():
    assert SPEC.read_text() == render(), "run: python -m app.export_openapi"


async def test_stubs_use_the_error_format(api):
    from tests.conftest import sign_in

    student = await sign_in(api)
    r = await student.get("/help/faqs")
    assert r.status_code == 501
    assert r.json()["error"]["code"] == "NOT_IMPLEMENTED"
