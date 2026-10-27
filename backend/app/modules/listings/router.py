import uuid

from fastapi import APIRouter, Response
from unirent_security import CurrentAccount

from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.schemas import PhotoOut
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

router = APIRouter(tags=["listings"])


@router.get("/categories", response_model=list[CategoryOut])
async def categories() -> list[CategoryOut]:
    return [CategoryOut(key=k, label=v) for k, v in CATEGORY_LABELS.items()]  # type: ignore[arg-type]


@router.post("/uploads/photos", response_model=UploadOut)
async def presign_photo_upload(body: UploadRequest, account: CurrentAccount) -> UploadOut:
    """A presigned URL to upload one photo straight to storage."""
    raise not_implemented()


@router.get("/listings/mine", response_model=list[ListingCard])
async def my_listings(
    account: CurrentAccount, session: SessionDep, status: ListingStatus | None = None
):
    raise not_implemented()


@router.post("/listings", response_model=ListingDetail, status_code=201)
async def create_listing(body: ListingCreate, account: CurrentAccount, session: SessionDep):
    """Publish a listing. Needs a linked payout account."""
    raise not_implemented()


@router.get("/listings/{listing_id}", response_model=ListingDetail)
async def get_listing(listing_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.patch("/listings/{listing_id}", response_model=ListingDetail)
async def update_listing(
    listing_id: uuid.UUID, body: ListingUpdate, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.post("/listings/{listing_id}/pause", response_model=ListingDetail)
async def pause_listing(listing_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.post("/listings/{listing_id}/resume", response_model=ListingDetail)
async def resume_listing(listing_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.post("/listings/{listing_id}/photos", response_model=PhotoOut, status_code=201)
async def add_listing_photo(
    listing_id: uuid.UUID, body: PhotoAdd, account: CurrentAccount, session: SessionDep
):
    raise not_implemented()


@router.delete("/listings/{listing_id}/photos/{photo_id}", status_code=204)
async def delete_listing_photo(
    listing_id: uuid.UUID, photo_id: uuid.UUID, account: CurrentAccount, session: SessionDep
) -> Response:
    raise not_implemented()


@router.get("/assets/mine", response_model=list[AssetOut])
async def my_assets(account: CurrentAccount, session: SessionDep):
    raise not_implemented()


@router.get("/assets/{asset_id}", response_model=AssetOut)
async def get_asset(asset_id: uuid.UUID, account: CurrentAccount, session: SessionDep):
    raise not_implemented()
