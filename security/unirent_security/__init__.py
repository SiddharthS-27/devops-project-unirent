"""UniRent security: sign-in, tokens, roles, ownership, rate limits and audit.

The functions other packages call are re-exported here."""

from unirent_security import audit
from unirent_security.accounts import AccountInfo, get_account, get_accounts, set_account_status
from unirent_security.errors import ApiError
from unirent_security.masking import mask_serial
from unirent_security.ownership import is_owner, require_owner
from unirent_security.passwords import hash_secret, verify_secret
from unirent_security.rate_limit import hit as rate_limit_hit
from unirent_security.rate_limit import rate_limit
from unirent_security.roles import (
    AccountContext,
    ActiveAccount,
    AdminAccount,
    CurrentAccount,
    StaffAccount,
    current_account,
    optional_account,
    require_active,
    require_role,
)

__all__ = [
    "AccountContext",
    "AccountInfo",
    "ActiveAccount",
    "AdminAccount",
    "ApiError",
    "CurrentAccount",
    "StaffAccount",
    "audit",
    "current_account",
    "get_account",
    "get_accounts",
    "hash_secret",
    "is_owner",
    "mask_serial",
    "optional_account",
    "rate_limit",
    "rate_limit_hit",
    "require_active",
    "require_owner",
    "require_role",
    "set_account_status",
    "verify_secret",
]
