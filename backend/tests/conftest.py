import uuid

import httpx
import pytest
import unirent_payments.db
import unirent_security.db
from sqlalchemy import text
from unirent_security.config import get_settings as security_settings
from unirent_security.rate_limit import LIMITS, Limit

from app.core.db import dispose_engine, get_engine
from app.core.redis import close_redis
from app.main import create_app


@pytest.fixture
async def client():
    app = create_app()
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    await close_redis()
    await dispose_engine()
    await unirent_security.db.reset()
    await unirent_payments.db.reset()


@pytest.fixture
async def db_ready():
    """Skip unless PostgreSQL is reachable and migrated."""
    try:
        async with get_engine().connect() as conn:
            await conn.execute(text("SELECT 1 FROM core.profiles LIMIT 1"))
            await conn.execute(text("SELECT 1 FROM security.accounts LIMIT 1"))
    except Exception as exc:  # noqa: BLE001
        pytest.skip(f"database unavailable: {exc}")


@pytest.fixture
async def api(client, db_ready, monkeypatch):
    """A client against a migrated database, with mock sign-in."""
    settings = security_settings()
    monkeypatch.setattr(settings, "ms_auth_mode", "mock")
    monkeypatch.setattr(settings, "phone_auth_mode", "mock")
    monkeypatch.setattr(settings, "environment", "test")
    # Every test student signs in from the same address.
    monkeypatch.setitem(LIMITS, "student_signin", Limit(10_000, 60))
    await unirent_security.db.redis().flushdb()
    return client


class Student:
    def __init__(self, client: httpx.AsyncClient, pair: dict):
        self.client = client
        self.id = uuid.UUID(pair["account"]["id"])
        self.email = pair["account"]["email"]
        self.headers = {"Authorization": f"Bearer {pair['access_token']}"}

    async def get(self, path, **kw):
        return await self.client.get("/api/v1" + path, headers=self.headers, **kw)

    async def post(self, path, **kw):
        # Like the app, every tap gets its own Idempotency-Key unless one is given.
        headers = {"Idempotency-Key": uuid.uuid4().hex, **self.headers, **kw.pop("headers", {})}
        return await self.client.post("/api/v1" + path, headers=headers, **kw)

    async def put(self, path, **kw):
        return await self.client.put("/api/v1" + path, headers=self.headers, **kw)

    async def patch(self, path, **kw):
        return await self.client.patch("/api/v1" + path, headers=self.headers, **kw)

    async def delete(self, path, **kw):
        return await self.client.delete("/api/v1" + path, headers=self.headers, **kw)


PROFILE = {
    "full_name": "Asha Rao",
    "roll_number": "CS21B001",
    "department": "Computer Science",
    "year": 3,
    "residence_type": "hostel",
    "hostel_name": "Ganga",
    "room_number": "214",
}


async def sign_in(client) -> Student:
    email = f"s{uuid.uuid4().hex[:10]}@college.edu"
    r = await client.post("/api/v1/auth/microsoft/mock-token", json={"email": email})
    r = await client.post("/api/v1/auth/microsoft", json=r.json())
    assert r.status_code == 200, r.text
    return Student(client, r.json())


async def onboard(client, profile=None) -> Student:
    """A student who has finished onboarding."""
    student = await sign_in(client)
    r = await student.put("/me/profile", json=profile or PROFILE)
    assert r.status_code == 200, r.text
    phone = "+91" + str(uuid.uuid4().int)[:10]
    token = await client.post(
        "/api/v1/auth/phone/mock-token", json={"phone": phone, "code": "123456"}
    )
    assert (await student.post("/auth/phone", json=token.json())).status_code == 200
    r = await student.post("/me/terms", json={"version": "2026-10"})
    assert r.json()["onboarding"]["complete"] is True
    return student


async def payout_ready(student: Student) -> None:
    """Give a student an activated payout account without calling Razorpay."""
    from datetime import UTC, datetime

    from unirent_payments.models import LinkedAccount

    from app.core.db import get_sessionmaker

    async with get_sessionmaker()() as session:
        session.add(
            LinkedAccount(
                account_id=student.id,
                razorpay_account_id=f"acc_{uuid.uuid4().hex[:14]}",
                route_product_id="acc_prd_test",
                status="activated",
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
        )
        await session.commit()


# A 1x1 JPEG, enough for storage round trips.
TINY_JPEG = bytes.fromhex(
    "ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707070909080a0c140d0c0b0b0c"
    "1912130f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432ffc000"
    "0b080001000101011100ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400"
    "b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c1"
    "1552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a63"
    "6465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6"
    "b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffda0008"
    "010100003f00fbd3ffd9"
)


async def upload_photo(student: Student, purpose: str = "listing") -> str:
    r = await student.post("/uploads/photos", json={"purpose": purpose})
    assert r.status_code == 200, r.text
    upload = r.json()
    async with httpx.AsyncClient() as raw:
        put = await raw.put(upload["upload_url"], content=TINY_JPEG, headers=upload["headers"])
    assert put.status_code == 200, put.text
    return upload["object_key"]


CAMERA = {
    "kind": "rent",
    "title": "Canon EOS 1500D camera",
    "description": "DSLR with 18-55mm kit lens, two batteries and a bag.",
    "category": "cameras",
    "condition": "good",
    "serial_number": "CN1500D-778812",
    "price_per_day_paise": 30000,
    "price_per_hour_paise": 2000,
    "pickup_point": "Ganga hostel gate",
}


async def lister(client) -> Student:
    """An onboarded student who can list."""
    student = await onboard(client)
    await payout_ready(student)
    return student


async def create_listing(student: Student, **overrides) -> dict:
    key = await upload_photo(student)
    body = {**CAMERA, "photo_keys": [key], **overrides}
    r = await student.post("/listings", json=body)
    assert r.status_code == 201, r.text
    return r.json()


async def approved_booking(client, **listing_overrides):
    """An owner, a renter and an approved rental between them."""
    from datetime import timedelta

    from app.core.clock import now

    owner = await lister(client)
    listing = await create_listing(owner, **listing_overrides)
    renter = await onboard(client)
    start = (now() + timedelta(hours=2)).replace(microsecond=0)
    period = {"start_at": start.isoformat(), "end_at": (start + timedelta(days=1)).isoformat()}
    if listing["kind"] == "sale":
        period = {}
    r = await renter.post("/bookings", json={"listing_id": listing["id"], **period})
    assert r.status_code == 201, r.text
    booking = r.json()
    r = await owner.post(f"/bookings/{booking['id']}/approve")
    assert r.status_code == 200, r.text
    return owner, renter, r.json()


async def pickup_photos(owner, renter, booking_id) -> None:
    for user in (owner, renter):
        key = await upload_photo(user, "handover")
        r = await user.post(f"/bookings/{booking_id}/pickup/photos", json={"object_keys": [key]})
        assert r.status_code == 200, r.text


async def pay_cash_and_hand_over(owner, renter, booking_id) -> dict:
    payment = (
        await renter.post(f"/bookings/{booking_id}/pickup/payment", json={"method": "cash"})
    ).json()
    r = await owner.post(f"/payments/{payment['id']}/mark-cash-paid")
    assert r.status_code == 200, r.text
    code = (await renter.post(f"/bookings/{booking_id}/pickup/otp")).json()["code"]
    r = await owner.post(f"/bookings/{booking_id}/pickup/otp/verify", json={"code": code})
    assert r.status_code == 200, r.text
    return r.json()


async def moderator(client) -> Student:
    """A signed-in moderator (password already changed)."""
    from unirent_security.staff_auth import create_staff_account

    from app.core.db import get_sessionmaker

    email = f"m{uuid.uuid4().hex[:10]}@unirent.in"
    async with get_sessionmaker()() as session:
        await create_staff_account(session, email, "Mod", "temporary-pass-1")
        await session.commit()
    r = await client.post(
        "/api/v1/auth/staff/password",
        json={
            "email": email,
            "current_password": "temporary-pass-1",
            "new_password": "a-new-pass-123",
        },
    )
    assert r.status_code == 200, r.text
    return Student(client, r.json())
