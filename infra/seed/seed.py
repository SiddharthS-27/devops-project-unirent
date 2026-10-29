"""Demo data: the admin, 2 moderators, 10 students and 20 listings.

Runs inside the api container (make seed) through the app's own services, so the
data obeys the same rules as real use. Safe to run twice: existing accounts are
left alone. Students sign in in mock mode with their email; their accounts use
the same Microsoft object ID the mock sign-in derives."""

import asyncio
import io
import os
import struct
import uuid
import zlib
from datetime import UTC, datetime

from minio import Minio
from sqlalchemy import select
from unirent_payments.models import LinkedAccount
from unirent_security import AccountContext
from unirent_security.models import Account
from unirent_security.staff_auth import create_staff_account

from app.core.config import get_settings
from app.core.db import get_sessionmaker
from app.main import create_app
from app.modules.listings import service as listings
from app.modules.listings.schemas import ListingCreate
from app.modules.profiles.models import Profile

MODERATOR_PASSWORD = "moderator-pass-1"
DEPARTMENTS = ["Computer Science", "Mechanical", "Electrical", "Civil", "Physics"]
HOSTELS = ["Ganga", "Cauvery", "Godavari", "Krishna"]
STUDENTS = [
    ("Asha Rao", "asha"),
    ("Ravi Kumar", "ravi"),
    ("Meera Iyer", "meera"),
    ("Arjun Nair", "arjun"),
    ("Divya Menon", "divya"),
    ("Karthik S", "karthik"),
    ("Sneha Reddy", "sneha"),
    ("Vikram Singh", "vikram"),
    ("Priya Das", "priya"),
    ("Rahul Jain", "rahul"),
]
# (owner index, kind, title, category, condition, day price or sale price in rupees)
LISTINGS = [
    (0, "rent", "Canon EOS 1500D camera", "cameras", "good", 300),
    (0, "rent", "Tripod with phone mount", "cameras", "like_new", 60),
    (1, "rent", "Hero Sprint cycle", "cycles", "good", 80),
    (1, "sale", "Engineering Mathematics by Grewal", "books", "fair", 350),
    (2, "rent", "Yamaha acoustic guitar", "instruments", "good", 150),
    (2, "rent", "Casio keyboard CT-S300", "instruments", "like_new", 200),
    (3, "rent", "Badminton racquet pair", "sports", "good", 40),
    (3, "sale", "Yoga mat", "sports", "new", 400),
    (4, "rent", "Electric kettle", "hostel", "good", 30),
    (4, "rent", "Table lamp", "hostel", "fair", 20),
    (4, "sale", "Study table fan", "hostel", "good", 900),
    (5, "rent", "JBL party speaker", "events", "good", 250),
    (5, "rent", "Fairy lights, 20 m", "events", "like_new", 50),
    (6, "rent", "Scientific calculator fx-991EX", "electronics", "good", 25),
    (6, "rent", "Arduino starter kit", "electronics", "good", 100),
    (7, "sale", "Data Structures by Cormen", "books", "good", 600),
    (7, "rent", "Drafter and drawing board", "other", "fair", 40),
    (8, "rent", "GoPro Hero 9", "cameras", "good", 450),
    (8, "rent", "Electric scooter charger", "cycles", "good", 30),
    (9, "rent", "Cricket kit bag", "sports", "fair", 120),
]
COLOURS = [(0x1F, 0x6F, 0xEB), (0x16, 0xA3, 0x4A), (0xEA, 0x58, 0x0C), (0x93, 0x33, 0xEA)]


def png(rgb: tuple[int, int, int], width: int = 480, height: int = 360) -> bytes:
    """A plain coloured PNG, so seeded listings have a photo without image files."""
    row = b"\x00" + bytes(rgb) * width
    raw = zlib.compress(row * height, 9)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


def mock_oid(email: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "mock-oid:" + email.lower()))


async def ensure_staff(session) -> None:
    admin_email = os.environ.get("UNIRENT_ADMIN_EMAIL", "admin@unirent.in")
    admin_password = os.environ.get("UNIRENT_ADMIN_PASSWORD", "change-me-admin-password")
    staff = [(admin_email, "Admin", admin_password, "admin")]
    staff += [
        (f"mod{i}@unirent.in", f"Moderator {i}", MODERATOR_PASSWORD, "moderator") for i in (1, 2)
    ]
    for email, name, password, role in staff:
        if await session.scalar(select(Account.id).where(Account.email == email)):
            continue
        await create_staff_account(session, email, name, password, role=role)
        print(f"  {role:<9} {email} / {password} (change on first login)")
    await session.commit()


async def ensure_students(session) -> list[Account]:
    domain = os.environ.get("UNIRENT_MS_ALLOWED_DOMAIN", "college.edu")
    accounts = []
    for n, (name, handle) in enumerate(STUDENTS):
        email = f"{handle}@{domain}"
        account = await session.scalar(select(Account).where(Account.email == email))
        if account is None:
            account = Account(
                id=uuid.uuid4(),
                email=email,
                role="student",
                status="active",
                display_name=name,
                ms_oid=mock_oid(email),
                phone=f"+9190000000{n:02d}",
                phone_verified_at=datetime.now(UTC),
            )
            session.add(account)
            await session.flush()
            session.add(
                Profile(
                    account_id=account.id,
                    full_name=name,
                    roll_number=f"CS2{n % 4}B{100 + n}",
                    department=DEPARTMENTS[n % len(DEPARTMENTS)],
                    year=1 + n % 4,
                    residence_type="hostel",
                    hostel_name=HOSTELS[n % len(HOSTELS)],
                    room_number=str(100 + n * 7),
                    terms_version="2026-10",
                    terms_accepted_at=datetime.now(UTC),
                )
            )
            print(f"  student   {email}")
        accounts.append(account)
    await session.commit()
    return accounts


async def ensure_payout_accounts(session, owners: list[Account]) -> None:
    for owner in owners:
        if await session.get(LinkedAccount, owner.id):
            continue
        session.add(
            LinkedAccount(
                account_id=owner.id,
                razorpay_account_id=f"acc_seed{owner.id.hex[:10]}",
                route_product_id="acc_prd_seed",
                status="activated",
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
        )
    await session.commit()


async def ensure_listings(session, students: list[Account]) -> None:
    settings = get_settings()
    storage = Minio(
        settings.storage_endpoint,
        access_key=settings.storage_access_key,
        secret_key=settings.storage_secret_key,
        secure=settings.storage_secure,
        region=settings.storage_region,
    )
    for n, (owner_index, kind, title, category, condition, rupees) in enumerate(LISTINGS):
        owner = students[owner_index]
        if await session.scalar(
            select(listings.Listing.id).where(
                listings.Listing.owner_id == owner.id, listings.Listing.title == title
            )
        ):
            continue
        key = f"listing/{owner.id}/{uuid.uuid4().hex}.png"
        image = png(COLOURS[n % len(COLOURS)])
        await asyncio.to_thread(
            storage.put_object,
            settings.storage_bucket,
            key,
            io.BytesIO(image),
            len(image),
            content_type="image/png",
        )
        prices = (
            {
                "price_per_day_paise": rupees * 100,
                "price_per_hour_paise": max(rupees * 100 // 6, 500),
            }
            if kind == "rent"
            else {"sale_price_paise": rupees * 100}
        )
        data = ListingCreate(
            kind=kind,
            title=title,
            description=f"{title}, available on campus. Message me with any questions.",
            category=category,
            condition=condition,
            serial_number=f"SN-{owner.id.hex[:4].upper()}{n:04d}",
            pickup_point=f"{HOSTELS[owner_index % len(HOSTELS)]} hostel gate",
            photo_keys=[key],
            **prices,
        )
        await listings.create(session, AccountContext(owner.id, "student", "active"), data)
        await session.commit()
        print(f"  listing   {title}")


async def main() -> None:
    create_app()  # wires the packages to the api's database and Redis
    async with get_sessionmaker()() as session:
        print("staff:")
        await ensure_staff(session)
        print("students:")
        students = await ensure_students(session)
        owners = sorted({students[i].id for i, *_ in LISTINGS})
        await ensure_payout_accounts(session, [s for s in students if s.id in owners])
        print("listings:")
        await ensure_listings(session, students)
    print("seeded")


if __name__ == "__main__":
    asyncio.run(main())
