"""Create the single admin account if it doesn't exist yet.

UNIRENT_ADMIN_EMAIL=... UNIRENT_ADMIN_PASSWORD=... python -m unirent_security.bootstrap_admin
"""

import asyncio
import os
import sys

from sqlalchemy import select

from unirent_security import db
from unirent_security.models import Account
from unirent_security.staff_auth import create_staff_account


async def main() -> int:
    email = os.environ.get("UNIRENT_ADMIN_EMAIL")
    password = os.environ.get("UNIRENT_ADMIN_PASSWORD")
    if not email or not password:
        print("set UNIRENT_ADMIN_EMAIL and UNIRENT_ADMIN_PASSWORD", file=sys.stderr)
        return 2
    async with db.sessionmaker()() as session:
        if await session.scalar(select(Account.id).where(Account.role == "admin")):
            print("admin already exists")
            return 0
        await create_staff_account(session, email, "Admin", password, role="admin")
        await session.commit()
    print(f"created admin {email}; change the password on first login")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
