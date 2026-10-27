"""Builders for the data a test needs. Every test makes its own users and
listings with unique names, so tests never depend on each other's data."""

import uuid
from typing import Any

import httpx

from fixtures.client import User, sign_in

# A 1x1 JPEG.
JPEG = bytes.fromhex(
    "ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707070909080a0c140d0c0b0b0c"
    "1912130f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432ffc000"
    "0b080001000101011100ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400"
    "b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c1"
    "1552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a63"
    "6465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6"
    "b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffda0008"
    "010100003f00fbd3ffd9"
)

PROFILE = {
    "full_name": "Test Student",
    "roll_number": "CS21B001",
    "department": "Computer Science",
    "year": 3,
    "residence_type": "hostel",
    "hostel_name": "Ganga",
    "room_number": "214",
}


def tag() -> str:
    return uuid.uuid4().hex[:8]


def phone() -> str:
    return "+91" + "9" + str(uuid.uuid4().int)[:9]


def onboarded(name: str = "Test Student") -> User:
    user = sign_in()
    user.ok("PUT", "/me/profile", json={**PROFILE, "full_name": name})
    with httpx.Client(base_url=user.http.base_url, timeout=20) as http:
        token = http.post(
            "/api/v1/auth/phone/mock-token", json={"phone": phone(), "code": "123456"}
        ).json()
    user.ok("POST", "/auth/phone", json=token)
    me = user.ok("POST", "/me/terms", json={"version": "2026-10"})
    assert me["onboarding"]["complete"], me
    return user


def link_payout(user: User) -> dict:
    return user.ok(
        "POST",
        "/payouts/account",
        201,
        json={
            "legal_name": "Test Owner",
            "email": user.email,
            "phone": "+919876543210",
            "account_number": "123456789012",
            "ifsc": "HDFC0001234",
            "beneficiary_name": "Test Owner",
        },
    )


def owner(name: str = "Test Owner") -> User:
    user = onboarded(name)
    assert link_payout(user)["ready"]
    return user


def upload(user: User, purpose: str = "listing") -> str:
    upload = user.ok("POST", "/uploads/photos", json={"purpose": purpose})
    put = httpx.put(upload["upload_url"], content=JPEG, headers=upload["headers"], timeout=20)
    assert put.status_code == 200, put.text
    return upload["object_key"]


def listing(user: User, **overrides: Any) -> dict:
    body = {
        "kind": "rent",
        "title": f"Test camera {tag()}",
        "description": "A camera for tests.",
        "category": "cameras",
        "condition": "good",
        "serial_number": f"SN-{tag()}",
        "price_per_day_paise": 30000,
        "price_per_hour_paise": 2000,
        "pickup_point": "Main gate",
        "photo_keys": [upload(user)],
        **overrides,
    }
    return user.ok("POST", "/listings", 201, json=body)
