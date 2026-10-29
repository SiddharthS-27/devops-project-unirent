import uuid

from tests.test_webhooks import _auth, env  # noqa: F401 - fixture
from unirent_payments.payments import mark_cash_paid, start_payment
from unirent_payments.refunds import issue_refund


async def test_history_shows_both_sides_with_refunds(env):  # noqa: F811
    _, client = env
    booking, payer, payee = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
    p = await start_payment(booking, "rent", payer, payee, 5000, "cash", "k1")
    await mark_cash_paid(p.id, payee)
    await issue_refund(p.id, 2000, uuid.uuid4())

    mine = (await client.get("/payments/history", headers=_auth(payer))).json()["items"]
    theirs = (await client.get("/payments/history", headers=_auth(payee))).json()["items"]
    assert [i["direction"] for i in mine] == ["paid"]
    assert [i["direction"] for i in theirs] == ["received"]
    assert mine[0]["booking_id"] == str(booking)
    assert mine[0]["refunds"][0]["status"] == "cash_pending"
    stranger = (await client.get("/payments/history", headers=_auth(uuid.uuid4()))).json()
    assert stranger["items"] == []
