import uuid
from datetime import UTC, datetime

from unirent_payments import db
from unirent_payments.models import LinkedAccount


async def ready_payee(status: str = "activated") -> tuple[uuid.UUID, str]:
    """A payee with a linked account, without calling Razorpay."""
    payee = uuid.uuid4()
    account = f"acc_{uuid.uuid4().hex[:14]}"
    async with db.sessionmaker()() as session:
        session.add(
            LinkedAccount(
                account_id=payee,
                razorpay_account_id=account,
                route_product_id="acc_prd_test",
                status=status,
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
        )
        await session.commit()
    return payee, account
