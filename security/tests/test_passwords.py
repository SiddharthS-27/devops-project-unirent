import pytest

from unirent_security.errors import ApiError
from unirent_security.passwords import hash_secret, verify_secret
from unirent_security.staff_auth import check_password_strength


def test_hash_is_argon2id_and_verifies():
    hashed = hash_secret("correct horse battery")
    assert hashed.startswith("$argon2id$")
    assert verify_secret("correct horse battery", hashed)
    assert not verify_secret("wrong", hashed)


def test_missing_or_broken_hash_never_verifies():
    assert not verify_secret("anything", None)
    assert not verify_secret("anything", "not-a-hash")


@pytest.mark.parametrize("password", ["short", "mod@college.edu", "MOD@college.edu"])
def test_weak_passwords_are_refused(password):
    with pytest.raises(ApiError) as err:
        check_password_strength(password, "mod@college.edu")
    assert err.value.code == "WEAK_PASSWORD"
