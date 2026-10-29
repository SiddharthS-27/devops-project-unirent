from tests.conftest import moderator, onboard


async def test_handoff_reply_and_close(api):
    student = await onboard(api)
    thread = (
        await student.post(
            "/help/handoff",
            json={
                "message": "My renter hasn't returned my camera",
                "transcript": [
                    {"author": "user", "text": "item not returned"},
                    {"author": "bot", "text": "Owners can escalate an hour into overdue."},
                ],
            },
        )
    ).json()
    assert [m["author"] for m in thread["messages"]] == ["user", "bot", "user"]

    mod = await moderator(api)
    inbox = (await mod.get("/staff/support/threads")).json()
    mine = next(t for t in inbox if t["id"] == thread["id"])
    assert mine["unanswered"] and mine["account_name"] == "Asha Rao"

    path = f"/support/threads/{thread['id']}"
    reply = await mod.post(f"/staff{path}/messages", json={"body": "I'll call them now."})
    assert reply.json()["author"] == "moderator"
    seen = (await student.get(path)).json()
    assert seen["messages"][-1]["body"] == "I'll call them now."

    stranger = await onboard(api)
    assert (await stranger.get(path)).status_code == 404
    assert (await student.get("/staff/support/threads")).status_code == 403

    await mod.post(f"/staff{path}/close")
    closed = await student.post(f"{path}/messages", json={"body": "Thanks!"})
    assert closed.json()["error"]["code"] == "THREAD_CLOSED"
