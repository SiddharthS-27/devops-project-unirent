"""Helpers that keep personal and sensitive data out of public responses."""

MASK = "•"


def mask_serial(value: str | None) -> str | None:
    """Show only the last 4 characters of a serial number."""
    if value is None:
        return None
    value = value.strip()
    if len(value) <= 4:
        return MASK * len(value)
    return MASK * (len(value) - 4) + value[-4:]


def mask_email(value: str | None) -> str | None:
    """a****@college.edu, for logs and staff-facing summaries."""
    if not value or "@" not in value:
        return value
    local, domain = value.split("@", 1)
    return f"{local[:1]}{MASK * 4}@{domain}"


def mask_phone(value: str | None) -> str | None:
    """+91******3210"""
    if not value or len(value) < 6:
        return value
    return value[:3] + MASK * (len(value) - 7) + value[-4:]
