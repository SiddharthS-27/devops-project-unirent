"""Object-level checks, the defence against broken object-level authorization.
A caller who may not see an object gets 404, so IDs can't be probed."""

import uuid

from unirent_security.errors import not_found
from unirent_security.roles import AccountContext


def is_owner(account: AccountContext, *owner_ids: uuid.UUID | None) -> bool:
    return any(owner_id is not None and owner_id == account.id for owner_id in owner_ids)


def require_owner(
    account: AccountContext,
    *owner_ids: uuid.UUID | None,
    allow_staff: bool = True,
    what: str = "Resource",
) -> None:
    """Allow the listed owners (for a booking: renter and owner) and, unless
    `allow_staff` is false, moderators and the admin. Everyone else gets 404."""
    if is_owner(account, *owner_ids):
        return
    if allow_staff and account.is_staff:
        return
    raise not_found(what)
