"""Serial numbers, residence details and emails never leak in public responses."""

import json
import re

import pytest

from fixtures.client import User
from fixtures.data import approved_booking, listing, onboarded, owner, tag

pytestmark = pytest.mark.security


def _text(user: User, path: str, **params) -> str:
    r = user.get(path, params=params)
    assert r.status_code == 200, (path, r.text)
    return json.dumps(r.json())


def test_public_responses_hide_serials_and_private_details():
    t = tag()
    lister = owner("Serial Owner")
    serial = f"SECRET-{t}-9876"
    item = listing(lister, title=f"Projector {t}", serial_number=serial)
    stranger = onboarded("Curious")

    responses = [
        _text(stranger, "/search", q=t),
        _text(stranger, "/search/suggest", q=t),
        _text(stranger, "/home"),
        _text(stranger, f"/listings/{item['id']}"),
        _text(stranger, f"/assets/{item['asset']['id']}"),
        _text(stranger, f"/profiles/{lister.id}"),
    ]
    for body in responses:
        assert serial not in body
        assert lister.email not in body
        for field in ("hostel_name", "room_number", "home_address", "roll_number"):
            assert f'"{field}"' not in body
    assert "9876" in responses[3]  # the last four characters are shown


def test_residence_is_revealed_only_to_the_approved_counterparty():
    lister, renter, booking = approved_booking()
    stranger = onboarded()
    assert "residence" in renter.ok("GET", f"/profiles/{lister.id}")
    assert "residence" not in stranger.ok("GET", f"/profiles/{lister.id}")
    body = json.dumps(stranger.ok("GET", f"/profiles/{renter.id}"))
    assert not re.search(r"\b\d{3}\b.*Ganga", body)
