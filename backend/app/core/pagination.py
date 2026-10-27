"""Opaque cursors. Search orders by computed scores, so the cursor is an offset."""

import base64

from app.core.errors import ApiError


def encode_offset(offset: int) -> str:
    return base64.urlsafe_b64encode(f"o:{offset}".encode()).decode().rstrip("=")


def decode_offset(cursor: str | None) -> int:
    if not cursor:
        return 0
    try:
        raw = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)).decode()
        kind, value = raw.split(":", 1)
        offset = int(value)
        if kind != "o" or offset < 0:
            raise ValueError
        return offset
    except (ValueError, UnicodeDecodeError):
        raise ApiError(422, "INVALID_CURSOR", "The cursor is not valid") from None
