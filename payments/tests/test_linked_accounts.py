import uuid

import pytest
from unirent_security.errors import ApiError

from tests.fake_razorpay import FakeRazorpay
from unirent_payments import linked_accounts
from unirent_payments.razorpay_client import RazorpayClient, use_client

DETAILS = {
    "legal_name": "Asha Rao",
    "email": "asha@college.edu",
    "phone": "+919876543210",
    "account_number": "123456789012",
    "ifsc": "HDFC0001234",
    "beneficiary_name": "Asha Rao",
}


@pytest.fixture
def fake():
    fake = FakeRazorpay()
    use_client(RazorpayClient(transport=fake.transport()))
    yield fake
    use_client(None)


async def test_linking_makes_the_owner_payout_ready(session, fake):
    owner = uuid.uuid4()
    assert not await linked_accounts.payout_ready(owner)
    linked = await linked_accounts.link_account(session, owner, **DETAILS)
    await session.commit()
    assert linked.razorpay_account_id.startswith("acc_")
    assert await linked_accounts.payout_ready(owner)
    paths = [p for _, p in fake.calls]
    assert any(p.endswith("/stakeholders") for p in paths)

    with pytest.raises(ApiError) as err:
        await linked_accounts.link_account(session, owner, **DETAILS)
    assert err.value.code == "PAYOUT_ACCOUNT_EXISTS"


async def test_account_under_review_is_not_ready(session, fake):
    fake.activation_status = "under_review"
    owner = uuid.uuid4()
    await linked_accounts.link_account(session, owner, **DETAILS)
    await session.commit()
    assert not await linked_accounts.payout_ready(owner)

    fake.activation_status = "activated"
    await linked_accounts.refresh_status(session, owner)
    await session.commit()
    assert await linked_accounts.payout_ready(owner)


async def test_provider_errors_become_api_errors(session, fake):
    fake.fail_next = 400
    with pytest.raises(ApiError) as err:
        await linked_accounts.link_account(session, uuid.uuid4(), **DETAILS)
    assert err.value.code == "PAYMENT_PROVIDER_ERROR"
