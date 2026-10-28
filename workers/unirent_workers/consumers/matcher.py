"""Saved-search alerts: when a listing is published, ask the backend whose saved
searches it matches and push to each of them."""

from unirent_workers.backend_api import BackendApi
from unirent_workers.push import Push, PushDelivery

MATCHER_TOPICS = ["listings.events"]


def make_handler(backend: BackendApi, delivery: PushDelivery):
    async def handle(event: dict) -> None:
        if event["type"] != "ListingPublished":
            return
        listing_id = event["payload"]["listing_id"]
        result = await backend.saved_search_matches(listing_id)
        notified: set[str] = set()
        for match in result["matches"]:
            account = str(match["account_id"])
            if account in notified:
                continue  # one push per student, however many searches match
            notified.add(account)
            name = match.get("name") or "your saved search"
            await delivery.deliver(
                Push(
                    account_id=account,
                    title="New match",
                    body=f"{result['title']} matches {name}.",
                    link=f"unirent://listing/{listing_id}",
                )
            )

    return handle
