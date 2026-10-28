"""Profiles and onboarding. Visibility is decided here, never by the app."""

import uuid
from typing import Annotated

from fastapi import Depends
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_security import AccountContext, AccountInfo, ActiveAccount, get_account, get_accounts

from app.core import storage
from app.core.clock import now
from app.core.db import get_sessionmaker
from app.core.errors import ApiError, not_found
from app.modules.bookings.models import HOLDS_SLOT, Booking
from app.modules.profiles.models import Profile
from app.modules.profiles.schemas import (
    Onboarding,
    ProfileCounterparty,
    ProfileIn,
    ProfileOwn,
    ProfilePublic,
    ProfileStaff,
    Residence,
    TrustSummary,
)

CURRENT_TERMS_VERSION = "2026-10"
NEW_BADGE_TRADES = 5


def onboarding_state(profile: Profile | None, account: AccountInfo) -> Onboarding:
    profile_complete = profile is not None
    phone_verified = account.phone_verified_at is not None
    terms_accepted = profile is not None and profile.terms_version == CURRENT_TERMS_VERSION
    return Onboarding(
        profile_complete=profile_complete,
        phone_verified=phone_verified,
        terms_accepted=terms_accepted,
        complete=profile_complete and phone_verified and terms_accepted,
    )


async def upsert_profile(session: AsyncSession, account_id: uuid.UUID, data: ProfileIn) -> Profile:
    if data.photo_key:
        await storage.confirm_upload(data.photo_key, "profile", account_id)
    profile = await session.get(Profile, account_id, with_for_update=True)
    if profile is None:
        profile = Profile(account_id=account_id)
        session.add(profile)
    for field, value in data.model_dump().items():
        setattr(profile, field, value)
    await session.flush()
    return profile


async def accept_terms(session: AsyncSession, account_id: uuid.UUID, version: str) -> Profile:
    if version != CURRENT_TERMS_VERSION:
        raise ApiError(409, "TERMS_OUTDATED", "Read the latest terms and accept them again")
    profile = await session.get(Profile, account_id, with_for_update=True)
    if profile is None:
        raise ApiError(409, "PROFILE_REQUIRED", "Fill in your profile first")
    profile.terms_version = version
    profile.terms_accepted_at = now()
    await session.flush()
    return profile


# Hooks the later modules fill in: trust scores, trade counts and the
# counterparty check all come from bookings and reviews.
async def trust_summaries(
    account_ids: list[uuid.UUID],
) -> dict[uuid.UUID, tuple[TrustSummary, TrustSummary]]:
    return {a: (TrustSummary(), TrustSummary()) for a in account_ids}


async def trade_counts(
    session: AsyncSession, account_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[int, int]]:
    """(completed trades, cancellations) per account."""
    return {a: (0, 0) for a in account_ids}


async def is_counterparty(
    session: AsyncSession, viewer_id: uuid.UUID, subject_id: uuid.UUID
) -> bool:
    """True when the two share a booking that is approved or later."""
    pair = or_(
        and_(Booking.renter_id == viewer_id, Booking.owner_id == subject_id),
        and_(Booking.renter_id == subject_id, Booking.owner_id == viewer_id),
    )
    found = await session.scalar(
        select(Booking.id).where(pair, Booking.status.in_(HOLDS_SLOT)).limit(1)
    )
    return found is not None


async def public_profiles(
    session: AsyncSession, profiles: list[Profile], accounts: dict[uuid.UUID, AccountInfo]
) -> dict[uuid.UUID, ProfilePublic]:
    ids = [p.account_id for p in profiles]
    trust = await trust_summaries(ids)
    counts = await trade_counts(session, ids)
    out = {}
    for p in profiles:
        account = accounts[p.account_id]
        lender, renter = trust[p.account_id]
        completed, cancellations = counts[p.account_id]
        out[p.account_id] = ProfilePublic(
            account_id=p.account_id,
            full_name=p.full_name,
            photo_url=storage.photo_url(p.photo_key),
            department=p.department,
            year=p.year,
            phone=account.phone,
            lender=lender,
            renter=renter,
            is_new=completed < NEW_BADGE_TRADES,
            completed_trades=completed,
            cancellation_count=cancellations,
            member_since=account.created_at,
        )
    return out


def _residence(p: Profile) -> Residence:
    return Residence(
        type=p.residence_type,  # type: ignore[arg-type]
        hostel_name=p.hostel_name,
        room_number=p.room_number,
        home_address=p.home_address,
    )


async def profile_for_viewer(
    session: AsyncSession, viewer: AccountContext, subject_id: uuid.UUID
) -> ProfilePublic:
    """The public view, plus residence for a counterparty after approval, plus email
    and roll number for staff. Students see all of their own."""
    profile = await session.get(Profile, subject_id)
    account = await get_account(subject_id)
    if profile is None or account is None:
        raise not_found("Profile")
    public = (await public_profiles(session, [profile], {subject_id: account}))[subject_id]
    base = public.model_dump(exclude={"view"})
    if viewer.id == subject_id:
        return ProfileOwn(
            **base,
            residence=_residence(profile),
            email=account.email,
            roll_number=profile.roll_number,
            status=account.status,
            photo_key=profile.photo_key,
        )
    if viewer.is_staff:
        return ProfileStaff(
            **base,
            residence=_residence(profile),
            email=account.email,
            roll_number=profile.roll_number,
            status=account.status,
        )
    if await is_counterparty(session, viewer.id, subject_id):
        return ProfileCounterparty(**base, residence=_residence(profile))
    return public


async def profiles_for(
    session: AsyncSession, account_ids: list[uuid.UUID]
) -> dict[uuid.UUID, ProfilePublic]:
    """Public views for many accounts at once (owner cards, request lists)."""
    ids = list(set(account_ids))
    rows = list(await session.scalars(select(Profile).where(Profile.account_id.in_(ids))))
    accounts = await get_accounts([p.account_id for p in rows])
    return await public_profiles(session, rows, accounts)


async def require_onboarded(account: ActiveAccount) -> AccountContext:
    """Dependency for student actions: active, with profile, phone and terms done."""
    if account.role != "student":
        raise ApiError(403, "STUDENTS_ONLY", "Only students can do this")
    async with get_sessionmaker()() as session:
        profile = await session.get(Profile, account.id)
    info = await get_account(account.id)
    if info is None or not onboarding_state(profile, info).complete:
        raise ApiError(403, "ONBOARDING_INCOMPLETE", "Finish setting up your profile first")
    return account


OnboardedStudent = Annotated[AccountContext, Depends(require_onboarded)]
