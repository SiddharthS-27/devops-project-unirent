import pytest

from unirent_security.config import get_settings
from unirent_security.errors import ApiError
from unirent_security.phone_otp import mock_firebase_token, verify_firebase_token


@pytest.fixture(autouse=True)
def mock_mode(monkeypatch):
    monkeypatch.setattr(get_settings(), "phone_auth_mode", "mock")
    monkeypatch.setattr(get_settings(), "environment", "test")


async def test_verified_number_comes_from_the_token():
    token = mock_firebase_token("+919876543210", "123456")
    assert await verify_firebase_token(token) == "+919876543210"


def test_wrong_code_gets_no_token():
    with pytest.raises(ApiError) as err:
        mock_firebase_token("+919876543210", "000000")
    assert err.value.code == "WRONG_CODE"


async def test_token_for_another_project_is_refused(monkeypatch):
    token = mock_firebase_token("+919876543210", "123456")
    monkeypatch.setattr(get_settings(), "firebase_project_id", "someone-else")
    with pytest.raises(ApiError) as err:
        await verify_firebase_token(token)
    assert err.value.code == "INVALID_PHONE_TOKEN"
