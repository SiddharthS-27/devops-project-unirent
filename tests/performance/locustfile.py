"""Load scenarios from the PPT's performance tests.

  Browsers            search, type-ahead, Home and listing detail
  HotListingCrowd     many students requesting one listing at once
  PaymentRetryStorm   repeated payment starts, method switches and webhook replays
  ListingPublisher    new listings matching many saved searches (push fan-out)

Run against the test profile (make test-load) or any stack:
  locust -f performance/locustfile.py --host http://localhost:8000
The setup creates one shared owner and hot listing before users start."""

import random
import sys
import uuid
from pathlib import Path

from locust import FastHttpUser, between, events, task

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fixtures.client import sim  # noqa: E402
from fixtures.data import (  # noqa: E402
    approved_booking,
    listing,
    onboarded,
    owner,
    period,
    pickup_photos,
    tag,
)

SEARCH_TERMS = ["cam", "camera", "cycle", "guitar", "book", "lamp", "kettle", "speaker", "tripod"]
shared: dict = {}
EXPECTED_CONFLICTS = {"REQUEST_EXISTS", "SLOT_TAKEN"}


@events.test_start.add_listener
def setup(environment, **_):
    """One owner with a hot listing, shared by every simulated student."""
    host = environment.host or "http://localhost:8000"
    import fixtures.client

    fixtures.client.BASE_URL = host
    lister = owner("Hot Owner")
    shared["owner"] = lister
    shared["hot"] = listing(lister, title=f"Hot camera {tag()}")


class Student(FastHttpUser):
    abstract = True
    wait_time = between(0.5, 2)

    def on_start(self):
        email = f"load{uuid.uuid4().hex[:10]}@college.edu"
        token = self.client.post("/api/v1/auth/microsoft/mock-token", json={"email": email}).json()
        pair = self.client.post("/api/v1/auth/microsoft", json=token).json()
        self.headers = {"Authorization": f"Bearer {pair['access_token']}"}

    def api(self, method, path, name=None, **kwargs):
        headers = {**self.headers, **kwargs.pop("headers", {})}
        if method != "GET":
            headers.setdefault("Idempotency-Key", uuid.uuid4().hex)
        url = "/api/v1" + path
        return self.client.request(method, url, headers=headers, name=name or path, **kwargs)


class Browsers(Student):
    weight = 6

    @task(4)
    def type_ahead(self):
        term = random.choice(SEARCH_TERMS)
        for n in range(1, len(term) + 1):
            self.api("GET", f"/search/suggest?q={term[:n]}", name="/search/suggest")

    @task(3)
    def search(self):
        sort = random.choice(["trust", "newest", "price_asc"])
        self.api("GET", f"/search?q={random.choice(SEARCH_TERMS)}&sort={sort}", name="/search")

    @task(2)
    def home(self):
        self.api("GET", "/home")

    @task(2)
    def listing_detail(self):
        self.api("GET", f"/listings/{shared['hot']['id']}", name="/listings/{id}")


class HotListingCrowd(Student):
    """Database contention on one listing: everyone requests it, the owner approves."""

    weight = 2

    def on_start(self):
        # These students need full profiles to request.
        self.user = onboarded("Crowd")
        self.headers = self.user.headers

    @task
    def request_hot_listing(self):
        slot = period(hours_ahead=random.randint(2, 400), hours=random.randint(1, 30))
        body = {"listing_id": shared["hot"]["id"], **slot}
        with self.api(
            "POST", "/bookings", name="/bookings [hot]", json=body, catch_response=True
        ) as r:
            # Losing the race is the expected outcome here, not an error.
            if r.status_code == 409 and r.json()["error"]["code"] in EXPECTED_CONFLICTS:
                r.success()
        if r.status_code == 201 and random.random() < 0.3:
            shared["owner"].post(f"/bookings/{r.json()['id']}/approve")


class PaymentRetryStorm(Student):
    """Repeated starts with one key, method switches and replayed webhooks."""

    weight = 1

    def on_start(self):
        self.lister, self.renter, booking = approved_booking()
        self.booking_id = booking["id"]
        pickup_photos(self.lister, self.renter, self.booking_id)
        self.headers = self.renter.headers
        self.key = uuid.uuid4().hex

    @task(3)
    def retry_same_key(self):
        self.api(
            "POST",
            f"/bookings/{self.booking_id}/pickup/payment",
            name="/pickup/payment [same key]",
            json={"method": "upi"},
            headers={"Idempotency-Key": self.key},
        )

    @task(1)
    def replay_webhooks(self):
        with sim() as s:
            hooks = s.get("/sim/webhooks", params={"event": "payment.captured"}).json()[-5:]
            for hook in hooks:
                s.post(f"/sim/webhooks/{hook['id']}/replay")


class ListingPublisher(Student):
    """Burst notification fan-out: each new listing matches many saved searches."""

    weight = 1

    def on_start(self):
        self.user = owner("Publisher")
        self.headers = self.user.headers

    @task
    def publish(self):
        listing(self.user, title=f"Camera bundle {tag()}")
