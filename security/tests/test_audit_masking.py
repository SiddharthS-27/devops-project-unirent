import uuid

import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import DBAPIError

from unirent_security import audit
from unirent_security.masking import mask_email, mask_phone, mask_serial
from unirent_security.models import AuditEntry
from unirent_security.roles import AccountContext


@pytest.mark.parametrize(
    "value, masked",
    [
        ("SN-12345678", "•••••••5678"),
        ("ABCD", "••••"),
        ("  XY12345 ", "•••2345"),
        (None, None),
    ],
)
def test_mask_serial_shows_only_last_four(value, masked):
    assert mask_serial(value) == masked


def test_mask_email_and_phone():
    assert mask_email("asha@college.edu") == "a••••@college.edu"
    assert mask_phone("+919876543210") == "+91••••••3210"


async def test_record_and_read_back(session):
    actor = AccountContext(uuid.uuid4(), "moderator", "active")
    ref = uuid.uuid4()
    await audit.record(actor, "appeal.ruled", audit.target("appeal", ref), {"charge": 500})
    rows = await audit.entries(target=f"appeal:{ref}")
    assert rows[0]["action"] == "appeal.ruled"
    assert rows[0]["actor_role"] == "moderator"
    assert rows[0]["details"] == {"charge": 500}


async def test_audit_log_refuses_updates_and_deletes(session):
    await audit.record(None, "test.entry", session=session)
    await session.commit()
    entry_id = await session.scalar(select(AuditEntry.id).order_by(AuditEntry.id.desc()))
    for statement in (
        f"UPDATE security.audit_log SET action = 'x' WHERE id = {entry_id}",
        f"DELETE FROM security.audit_log WHERE id = {entry_id}",
    ):
        with pytest.raises(DBAPIError):
            await session.execute(text(statement))
        await session.rollback()
