"""Argon2id hashing for staff passwords and any other secret we must check later."""

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

_hasher = PasswordHasher()  # Argon2id with the library's recommended parameters

# Verifying against this keeps the timing the same when the account doesn't exist.
_DUMMY_HASH = _hasher.hash("unirent-dummy-password")


def hash_secret(secret: str) -> str:
    return _hasher.hash(secret)


def verify_secret(secret: str, hashed: str | None) -> bool:
    try:
        return _hasher.verify(hashed or _DUMMY_HASH, secret) and hashed is not None
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def needs_rehash(hashed: str) -> bool:
    return _hasher.check_needs_rehash(hashed)
