import pytest

from tests.conftest import onboard


@pytest.mark.parametrize(
    "message, expected",
    [
        ("how much is the late fee?", "What is the late fee?"),
        ("Can I cancel my booking", "Can I cancel a booking?"),
        ("my item is not returned yet", "What if my item isn't returned?"),
        ("is there any deposit", "Is there a deposit or a platform fee?"),
        ("how to extend rental", "Can I extend my rental?"),
    ],
)
async def test_known_questions_get_their_answer(api, message, expected):
    student = await onboard(api)
    faqs = {f["id"]: f for f in (await student.get("/help/faqs")).json()}
    reply = (await student.post("/help/chat", json={"message": message})).json()
    assert reply["kind"] == "answer", reply
    assert faqs[reply["faq_id"]]["question"] == expected


async def test_late_fee_answer_uses_the_current_rule(api):
    student = await onboard(api)
    reply = (await student.post("/help/chat", json={"message": "late fee?"})).json()
    assert "grace period" in reply["text"] and "{" not in reply["text"]


async def test_anything_else_falls_back_to_faqs_or_a_moderator(api):
    student = await onboard(api)
    body = {"message": "what's the weather tomorrow"}
    reply = (await student.post("/help/chat", json=body)).json()
    assert reply["kind"] == "fallback"
    assert reply["actions"] == ["see_faqs", "talk_to_moderator"]
