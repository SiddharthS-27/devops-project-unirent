"""Dependencies shared by the core routers."""

from typing import Annotated

from fastapi import Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import AccountContext, optional_account, rate_limit_hit
from unirent_security.rate_limit import client_ip

from app.core.db import get_session

SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def default_rate_limit(
    request: Request, account: Annotated[AccountContext | None, Depends(optional_account)]
) -> None:
    """120 requests a minute per signed-in account, or per IP for guests."""
    subject = f"acct:{account.id}" if account else f"ip:{client_ip(request)}"
    await rate_limit_hit("default", subject)


IdempotencyKey = Annotated[
    str,
    Header(
        alias="Idempotency-Key",
        min_length=8,
        max_length=100,
        description="Required on every request that moves money or changes a booking. "
        "Reuse the same key when retrying the same action.",
    ),
]
