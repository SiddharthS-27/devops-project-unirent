"""A logging filter that keeps personal data and secrets out of the logs.

It rewrites each record's message and extra fields: emails, phone numbers,
bearer tokens and JWTs, Razorpay secrets and signatures, and residence details
(hostel, room, home address) are replaced before any handler sees them."""

import logging
import re
from typing import Any

from unirent_security.masking import mask_email, mask_phone

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE = re.compile(r"(?<![\w+])(?:\+91[\s-]?)?[6-9]\d{9}(?!\d)")
BEARER = re.compile(r"(?i)bearer\s+[A-Za-z0-9._~+/-]+=*")
JWT = re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")
SENSITIVE_KEYS = {
    "password",
    "current_password",
    "new_password",
    "temporary_password",
    "token",
    "access_token",
    "refresh_token",
    "id_token",
    "firebase_id_token",
    "authorization",
    "razorpay_signature",
    "key_secret",
    "account_number",
    "ifsc",
    "hostel_name",
    "room_number",
    "home_address",
    "residence",
    "code",
}
REDACTED = "[redacted]"
_RESERVED = set(logging.makeLogRecord({}).__dict__) | {"message", "asctime"}


def mask_text(text: str) -> str:
    text = BEARER.sub("Bearer " + REDACTED, text)
    text = JWT.sub(REDACTED, text)
    text = EMAIL.sub(lambda m: mask_email(m.group()) or REDACTED, text)
    return PHONE.sub(lambda m: mask_phone(m.group().replace(" ", "").replace("-", "")) or "", text)


def mask_value(key: str, value: Any) -> Any:
    if key.lower() in SENSITIVE_KEYS:
        return REDACTED
    if isinstance(value, str):
        return mask_text(value)
    if isinstance(value, dict):
        return {k: mask_value(str(k), v) for k, v in value.items()}
    if isinstance(value, list | tuple):
        return [mask_value(key, v) for v in value]
    return value


class MaskingFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        if record.args:
            record.msg = record.getMessage()
            record.args = None
        if isinstance(record.msg, str):
            record.msg = mask_text(record.msg)
        for key, value in list(record.__dict__.items()):
            if key not in _RESERVED and not key.startswith("_"):
                setattr(record, key, mask_value(key, value))
        return True


def install(logger: logging.Logger | None = None) -> None:
    """Attach the filter to every handler of `logger` (the root by default)."""
    target = logger or logging.getLogger()
    for handler in target.handlers:
        if not any(isinstance(f, MaskingFilter) for f in handler.filters):
            handler.addFilter(MaskingFilter())
