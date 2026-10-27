import uuid

import pytest

from unirent_security import db
from unirent_security.accounts import set_account_status
from unirent_security.errors import ApiError
from unirent_security.models import Account, RefreshToken
from unirent_security.roles import _context_from_token
from unirent_security.tokens import issue_access_token, issue_refresh_token


async def _student(session) -> Account:
    account = Account(id=uuid.uuid4(), email=f"{uuid.uuid4().hex[:8]}@college.edu", role="student")
    account.status = "active"
    session.add(account)
    await session.flush()
    return account


async def test_ban_revokes_tokens_and_blocks_at_once(session):
    account = await _student(session)
    token = issue_access_token(account)
    await issue_refresh_token(session, account.id)
    await session.commit()

    assert (await _context_from_token(token)).status == "active"
    previous = await set_account_status(account.id, "banned", None, "test", session)
    await session.commit()
    assert previous == "active"

    with pytest.raises(ApiError) as err:
        await _context_from_token(token)  # the old token says active
    assert err.value.code == "ACCOUNT_DISABLED"
    refresh = await session.get(RefreshToken, (await _refresh_ids(session, account.id))[0])
    assert refresh.revoked_at is not None


async def test_suspension_shows_on_the_next_request(session):
    account = await _student(session)
    token = issue_access_token(account)
    await session.commit()
    await set_account_status(account.id, "suspended", None, "late returns", session)
    await session.commit()
    assert (await _context_from_token(token)).status == "suspended"
    await set_account_status(account.id, "active", None, "appeal upheld", session)
    await session.commit()
    assert (await _context_from_token(token)).status == "active"


async def test_unknown_status_is_refused():
    with pytest.raises(ApiError):
        await set_account_status(uuid.uuid4(), "frozen", None, "x")


async def _refresh_ids(session, account_id):
    from sqlalchemy import select

    return list(
        await session.scalars(select(RefreshToken.id).where(RefreshToken.account_id == account_id))
    )


@pytest.fixture(autouse=True)
async def _close_redis():
    yield
    await db.reset()
