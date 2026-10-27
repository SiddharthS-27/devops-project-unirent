import uuid

from fastapi import APIRouter, Response
from unirent_security import CurrentAccount

from app.core import storage
from app.core.deps import SessionDep
from app.core.schemas import PhotoOut
from app.modules.listings import service
from app.modules.listings.schemas import (
    CATEGORY_LABELS,
    AssetOut,
    CategoryOut,
    ListingCard,
    ListingCreate,
    ListingDetail,
    ListingStatus,
    ListingUpdate,
    PhotoAdd,
    UploadOut,
    UploadRequest,
)
from app.modules.profiles.service import OnboardedStudent

router = APIRouter(tags=["listings"])


@router.get("/categories", response_model=list[CategoryOut])
async def categories() -> list[CategoryOut]:
    return [CategoryOut(key=k, label=v) for k, v in CATEGORY_LABELS.items()]  # type: ignore[arg-type]


@router.post("/uploads/photos", response_model=UploadOut)
async def presign_photo_upload(body: UploadRequest, account: CurrentAccount) -> UploadOut:
    """A presigned URL to upload one photo straight to storage. Resize to at most
    1600 px first, then confirm the object_key where the photo belongs."""
    key = storage.new_key(body.purpose, account.id, body.content_type)
    url, headers, expires_at = storage.upload_url(key, body.content_type)
    return UploadOut(object_key=key, upload_url=url, headers=headers, expires_at=expires_at)


@router.get("/listings/mine", response_model=list[ListingCard])
async def my_listings(
    account: CurrentAccount, session: SessionDep, status: ListingStatus | None = None
):
    return await service.mine(session, account, status)


@router.post("/listings", response_model=ListingDetail, status_code=201)
async def create_listing(body: ListingCreate, account: OnboardedStudent, session: SessionDep):
    """Publish a listing. Needs a linked payout account."""
    listing = await service.create(session, account, body)
    await session.commit()
    return await service.detail(session, listing, account)


@router.get("/listings/{listing_id}", response_model=ListingDetail)
async def get_listing(listing_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    listing = await service.get_listing(session, listing_id)
    return await service.detail(session, listing, account)


@router.patch("/listings/{listing_id}", response_model=ListingDetail)
async def update_listing(
    listing_id: uuid.UUID, body: ListingUpdate, account: CurrentAccount, session: SessionDep
):
    """Refused while a booking is approved or active (price and terms are locked)."""
    listing = await service.update(session, listing_id, account, body)
    await session.commit()
    return await service.detail(session, listing, account)


@router.post("/listings/{listing_id}/pause", response_model=ListingDetail)
async def pause_listing(listing_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    listing = await service.set_paused(session, listing_id, account, paused=True)
    await session.commit()
    return await service.detail(session, listing, account)


@router.post("/listings/{listing_id}/resume", response_model=ListingDetail)
async def resume_listing(listing_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    listing = await service.set_paused(session, listing_id, account, paused=False)
    await session.commit()
    return await service.detail(session, listing, account)


@router.post("/listings/{listing_id}/photos", response_model=PhotoOut, status_code=201)
async def add_listing_photo(
    listing_id: uuid.UUID, body: PhotoAdd, account: CurrentAccount, session: SessionDep
):
    photo = await service.add_photo(session, listing_id, account, body.object_key)
    await session.commit()
    return PhotoOut(id=str(photo.id), url=storage.photo_url(photo.object_key) or "")


@router.delete("/listings/{listing_id}/photos/{photo_id}", status_code=204)
async def delete_listing_photo(
    listing_id: uuid.UUID, photo_id: uuid.UUID, account: CurrentAccount, session: SessionDep
) -> Response:
    await service.delete_photo(session, listing_id, photo_id, account)
    await session.commit()
    return Response(status_code=204)


@router.get("/assets/mine", response_model=list[AssetOut])
async def my_assets(account: CurrentAccount, session: SessionDep):
    """Items you own, including ones you bought, so you can relist them."""
    return await service.my_assets(session, account)


@router.get("/assets/{asset_id}", response_model=AssetOut)
async def get_asset(asset_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    return await service.get_asset(session, asset_id, account)
