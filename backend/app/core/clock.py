"""The one place the backend reads the time. Always timezone-aware UTC."""

from datetime import UTC, datetime, timedelta

_offset = timedelta(0)


def now() -> datetime:
    return datetime.now(UTC) + _offset


def set_offset(offset: timedelta) -> None:
    """Shift the clock. Only the staging clock endpoint calls this."""
    global _offset
    _offset = offset


def get_offset() -> timedelta:
    return _offset
