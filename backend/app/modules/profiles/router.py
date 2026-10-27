import uuid

from fastapi import APIRouter
from unirent_security import CurrentAccount, get_account

from app.core.deps import SessionDep
from app.core.errors import ApiError
from app.modules.profiles import service
from app.modules.profiles.models import Profile
from app.modules.profiles.schemas import (
    AccountSummary,
    MeOut,
    ProfileIn,
    ProfileOwn,
    ProfileView,
    TermsIn,
)

router = APIRouter(tags=["profiles"])


async def _me(session, account) -> MeOut:
    info = await get_account(account.id)
    if info is None:
        raise ApiError(401, "UNAUTHENTICATED", "Sign in again")
    profile = await session.get(Profile, account.id)
    own = None
    if profile is not None:
        own = await service.profile_for_viewer(session, account, account.id)
    return MeOut(
        account=AccountSummary(id=info.id, email=info.email, role=info.role, status=info.status),
        profile=own,
        onboarding=service.onboarding_state(profile, info),
        current_terms_version=service.CURRENT_TERMS_VERSION,
    )


@router.get("/me", response_model=MeOut)
async def get_me(account: CurrentAccount, session: SessionDep) -> MeOut:
    """The signed-in account, its profile and what is left of onboarding."""
    return await _me(session, account)


@router.put("/me/profile", response_model=ProfileOwn)
async def put_profile(body: ProfileIn, account: CurrentAccount, session: SessionDep):
    """Create or edit the profile. Every field is editable; the email isn't on it."""
    if account.role != "student":
        raise ApiError(403, "STUDENTS_ONLY", "Only students have profiles")
    await service.upsert_profile(session, account.id, body)
    await session.commit()
    return await service.profile_for_viewer(session, account, account.id)


@router.post("/me/terms", response_model=MeOut)
async def accept_terms(body: TermsIn, account: CurrentAccount, session: SessionDep) -> MeOut:
    await service.accept_terms(session, account.id, body.version)
    await session.commit()
    return await _me(session, account)


@router.get("/profiles/{account_id}", response_model=ProfileView)
async def get_profile(account_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    """Public view; residence is added for the counterparty of an approved
    booking, email and roll number for staff."""
    return await service.profile_for_viewer(session, account, account_id)
