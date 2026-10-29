"""Listings and assets."""

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from unirent_payments import current_late_fee_rule as payments_late_fee_rule
from unirent_payments import payout_ready
from unirent_security import AccountContext, mask_serial, require_owner

from app.core import storage
from app.core.clock import now
from app.core.errors import ApiError, not_found
from app.core.outbox import emit
from app.core.schemas import PhotoOut
from app.modules.bookings.models import HOLDS_SLOT, Booking
from app.modules.listings.models import Asset, AssetEvent, Listing, ListingPhoto
from app.modules.listings.schemas import (
    AssetHistoryEntry,
    AssetOut,
    BlockedSlot,
    LateFeeRuleOut,
    ListingCard,
    ListingCreate,
    ListingDetail,
    ListingUpdate,
    OwnerCard,
    OwnerSummary,
)
from app.modules.profiles.service import profiles_for

MAX_PHOTOS = 8


LOCKING = ("approved", "active", "overdue", "returning", "in_appeal")


async def has_locking_booking(session: AsyncSession, listing_id: uuid.UUID) -> bool:
    """True while a booking for this listing is approved or active: no edits then."""
    found = await session.scalar(
        select(Booking.id)
        .where(Booking.listing_id == listing_id, Booking.status.in_(LOCKING))
        .limit(1)
    )
    return found is not None


async def blocked_slots(session: AsyncSession, listing_id: uuid.UUID) -> list[BlockedSlot]:
    """Future slots held by approved or later rentals."""
    rows = await session.execute(
        select(Booking.start_at, Booking.end_at)
        .where(
            Booking.listing_id == listing_id,
            Booking.kind == "rent",
            Booking.status.in_(HOLDS_SLOT),
            Booking.end_at > now(),
        )
        .order_by(Booking.start_at)
    )
    return [BlockedSlot(start_at=r.start_at, end_at=r.end_at) for r in rows]


async def pending_request_count(session: AsyncSession, listing_id: uuid.UUID) -> int:
    count = await session.scalar(
        select(func.count()).where(Booking.listing_id == listing_id, Booking.status == "requested")
    )
    return count or 0


async def current_late_fee_rule() -> LateFeeRuleOut | None:
    rule = await payments_late_fee_rule()
    return LateFeeRuleOut(
        id=rule.id,
        grace_minutes=rule.grace_minutes,
        base_fee_paise=rule.base_fee_paise,
        hourly_percent_bp=rule.hourly_percent_bp,
        effective_from=rule.effective_from,
    )


async def get_listing(
    session: AsyncSession, listing_id: uuid.UUID, *, lock: bool = False
) -> Listing:
    listing = await session.get(Listing, listing_id, with_for_update=lock)
    if listing is None:
        raise not_found("Listing")
    return listing


def _visible_to(listing: Listing, viewer: AccountContext) -> bool:
    """Active listings are public; others only to the owner and staff."""
    return listing.status == "active" or listing.owner_id == viewer.id or viewer.is_staff


async def _photos(session: AsyncSession, listing_ids: list[uuid.UUID]):
    rows = await session.scalars(
        select(ListingPhoto)
        .where(ListingPhoto.listing_id.in_(listing_ids))
        .order_by(ListingPhoto.listing_id, ListingPhoto.position)
    )
    by_listing: dict[uuid.UUID, list[ListingPhoto]] = {}
    for photo in rows:
        by_listing.setdefault(photo.listing_id, []).append(photo)
    return by_listing


async def cards(session: AsyncSession, listings: list[Listing]) -> list[ListingCard]:
    if not listings:
        return []
    owners = await profiles_for(session, [listing.owner_id for listing in listings])
    photos = await _photos(session, [listing.id for listing in listings])
    out = []
    for listing in listings:
        owner = owners.get(listing.owner_id)
        first = photos.get(listing.id, [None])[0]
        out.append(
            ListingCard(
                id=listing.id,
                kind=listing.kind,  # type: ignore[arg-type]
                status=listing.status,  # type: ignore[arg-type]
                title=listing.title,
                category=listing.category,  # type: ignore[arg-type]
                price_per_hour_paise=listing.price_per_hour_paise,
                price_per_day_paise=listing.price_per_day_paise,
                sale_price_paise=listing.sale_price_paise,
                photo_url=storage.photo_url(first.object_key) if first else None,
                pickup_point=listing.pickup_point,
                owner=OwnerSummary(
                    account_id=listing.owner_id,
                    full_name=owner.full_name if owner else "UniRent user",
                    photo_url=owner.photo_url if owner else None,
                    lender_trust=owner.lender.score if owner else None,
                    is_new=owner.is_new if owner else True,
                ),
                created_at=listing.created_at,
            )
        )
    return out


async def asset_out(session: AsyncSession, asset: Asset, viewer: AccountContext) -> AssetOut:
    events = await session.scalars(
        select(AssetEvent).where(AssetEvent.asset_id == asset.id).order_by(AssetEvent.at)
    )
    full_serial = asset.owner_id == viewer.id or viewer.is_staff
    return AssetOut(
        id=asset.id,
        owner_id=asset.owner_id,
        condition=asset.condition,  # type: ignore[arg-type]
        manufacture_date=asset.manufacture_date,
        serial_number=asset.serial_number if full_serial else mask_serial(asset.serial_number),
        rental_count=asset.rental_count,
        history=[
            AssetHistoryEntry(
                at=e.at,
                kind=e.kind,  # type: ignore[arg-type]
                summary=e.summary,
                amount_paise=e.amount_paise,
                photos=[PhotoOut(id=key, url=storage.photo_url(key) or "") for key in e.photo_keys],
            )
            for e in events
        ],
    )


async def detail(session: AsyncSession, listing: Listing, viewer: AccountContext) -> ListingDetail:
    if not _visible_to(listing, viewer):
        raise not_found("Listing")
    card = (await cards(session, [listing]))[0]
    owner = (await profiles_for(session, [listing.owner_id])).get(listing.owner_id)
    asset = await session.get(Asset, listing.asset_id)
    photos = (await _photos(session, [listing.id])).get(listing.id, [])
    is_mine = listing.owner_id == viewer.id
    locked = await has_locking_booking(session, listing.id)
    return ListingDetail(
        **card.model_dump(exclude={"owner"}),
        description=listing.description,
        condition=asset.condition,  # type: ignore[arg-type,union-attr]
        manufacture_date=asset.manufacture_date,  # type: ignore[union-attr]
        photos=[PhotoOut(id=str(p.id), url=storage.photo_url(p.object_key) or "") for p in photos],
        owner=OwnerCard(
            **card.owner.model_dump(),
            lender_rating=owner.lender.rating if owner else None,
            cancellation_count=owner.cancellation_count if owner else 0,
            phone=owner.phone if owner else None,
        ),
        asset=await asset_out(session, asset, viewer),  # type: ignore[arg-type]
        late_fee_rule=await current_late_fee_rule() if listing.kind == "rent" else None,
        unavailable=await blocked_slots(session, listing.id),
        is_mine=is_mine,
        can_edit=is_mine and not locked and listing.status in ("active", "paused"),
        pending_request_count=await pending_request_count(session, listing.id) if is_mine else None,
    )


async def _attach_photos(
    session: AsyncSession, listing: Listing, keys: list[str], owner_id: uuid.UUID
) -> list[ListingPhoto]:
    count = await session.scalar(select(func.count()).where(ListingPhoto.listing_id == listing.id))
    if (count or 0) + len(keys) > MAX_PHOTOS:
        raise ApiError(422, "TOO_MANY_PHOTOS", f"A listing can have up to {MAX_PHOTOS} photos")
    added = []
    for offset, key in enumerate(keys):
        await storage.confirm_upload(key, "listing", owner_id)
        photo = ListingPhoto(
            id=uuid.uuid4(), listing_id=listing.id, object_key=key, position=(count or 0) + offset
        )
        session.add(photo)
        added.append(photo)
    await session.flush()
    return added


def _published_payload(listing: Listing) -> dict:
    return {
        "listing_id": str(listing.id),
        "owner_id": str(listing.owner_id),
        "title": listing.title,
        "kind": listing.kind,
        "category": listing.category,
        "price_paise": listing.price_paise,
    }


async def create(session: AsyncSession, owner: AccountContext, data: ListingCreate) -> Listing:
    """Publish a listing; the owner must have a ready payout account."""
    if not await payout_ready(owner.id):
        raise ApiError(
            409, "PAYOUT_ACCOUNT_REQUIRED", "Link a Razorpay account before your first listing"
        )
    if data.asset_id:
        asset = await session.get(Asset, data.asset_id, with_for_update=True)
        if asset is None or asset.owner_id != owner.id:
            raise not_found("Asset")
        asset.condition = data.condition
        asset.category = data.category
        if data.serial_number:
            asset.serial_number = data.serial_number
        if data.manufacture_date:
            asset.manufacture_date = data.manufacture_date
    else:
        asset = Asset(
            id=uuid.uuid4(),
            owner_id=owner.id,
            category=data.category,
            condition=data.condition,
            manufacture_date=data.manufacture_date,
            serial_number=data.serial_number,
        )
        session.add(asset)
    await session.flush()

    at = now()
    listing = Listing(
        id=uuid.uuid4(),
        asset_id=asset.id,
        owner_id=owner.id,
        kind=data.kind,
        status="active",
        title=data.title,
        description=data.description,
        category=data.category,
        price_per_hour_paise=data.price_per_hour_paise,
        price_per_day_paise=data.price_per_day_paise,
        sale_price_paise=data.sale_price_paise,
        pickup_point=data.pickup_point,
        created_at=at,
        updated_at=at,
    )
    session.add(listing)
    try:
        await session.flush()
    except Exception as exc:  # the one-open-listing-per-asset index
        raise ApiError(409, "ASSET_ALREADY_LISTED", "This item already has a listing") from exc
    await _attach_photos(session, listing, data.photo_keys, owner.id)
    session.add(
        AssetEvent(
            id=uuid.uuid4(),
            asset_id=asset.id,
            at=at,
            kind="listed",
            summary=f"Listed for {'rent' if data.kind == 'rent' else 'sale'}",
        )
    )
    emit(session, "ListingPublished", listing.id, _published_payload(listing))
    return listing


async def _owned_for_edit(
    session: AsyncSession, listing_id: uuid.UUID, owner: AccountContext
) -> Listing:
    listing = await get_listing(session, listing_id, lock=True)
    require_owner(owner, listing.owner_id, allow_staff=False, what="Listing")
    if listing.status in ("sold", "removed"):
        raise ApiError(409, "LISTING_CLOSED", f"This listing is {listing.status}")
    if await has_locking_booking(session, listing.id):
        raise ApiError(409, "LISTING_LOCKED", "A booking is approved or active; edit after it ends")
    return listing


async def update(
    session: AsyncSession, listing_id: uuid.UUID, owner: AccountContext, data: ListingUpdate
) -> Listing:
    listing = await _owned_for_edit(session, listing_id, owner)
    changes = data.model_dump(exclude_unset=True)
    if listing.kind == "rent" and changes.get("sale_price_paise"):
        raise ApiError(422, "INVALID_PRICE", "Rent listings have no sale price")
    if listing.kind == "sale" and (
        changes.get("price_per_hour_paise") or changes.get("price_per_day_paise")
    ):
        raise ApiError(422, "INVALID_PRICE", "Sale listings have one fixed price")
    asset = await session.get(Asset, listing.asset_id, with_for_update=True)
    for field, value in changes.items():
        if field in ("condition", "manufacture_date", "serial_number"):
            setattr(asset, field, value)
        else:
            setattr(listing, field, value)
        if field == "category":
            asset.category = value  # type: ignore[union-attr]
    if listing.kind == "rent" and not (listing.price_per_hour_paise or listing.price_per_day_paise):
        raise ApiError(422, "INVALID_PRICE", "Rent listings need an hourly or daily price")
    listing.updated_at = now()
    await session.flush()
    return listing


async def set_paused(
    session: AsyncSession, listing_id: uuid.UUID, owner: AccountContext, paused: bool
) -> Listing:
    listing = await get_listing(session, listing_id, lock=True)
    require_owner(owner, listing.owner_id, allow_staff=False, what="Listing")
    allowed_from = "active" if paused else "paused"
    if listing.status != allowed_from:
        raise ApiError(409, "LISTING_STATE", f"A {listing.status} listing can't do that")
    listing.status = "paused" if paused else "active"
    listing.updated_at = now()
    await session.flush()
    return listing


async def add_photo(
    session: AsyncSession, listing_id: uuid.UUID, owner: AccountContext, key: str
) -> ListingPhoto:
    listing = await _owned_for_edit(session, listing_id, owner)
    return (await _attach_photos(session, listing, [key], owner.id))[0]


async def delete_photo(
    session: AsyncSession, listing_id: uuid.UUID, photo_id: uuid.UUID, owner: AccountContext
) -> None:
    listing = await _owned_for_edit(session, listing_id, owner)
    photo = await session.get(ListingPhoto, photo_id)
    if photo is None or photo.listing_id != listing.id:
        raise not_found("Photo")
    remaining = await session.scalar(
        select(func.count()).where(ListingPhoto.listing_id == listing.id)
    )
    if (remaining or 0) <= 1:
        raise ApiError(409, "LAST_PHOTO", "A listing needs at least one photo")
    await session.delete(photo)


async def mine(
    session: AsyncSession, owner: AccountContext, status: str | None
) -> list[ListingCard]:
    stmt = select(Listing).where(Listing.owner_id == owner.id).order_by(Listing.created_at.desc())
    if status:
        stmt = stmt.where(Listing.status == status)
    return await cards(session, list(await session.scalars(stmt)))


async def my_assets(session: AsyncSession, owner: AccountContext) -> list[AssetOut]:
    rows = await session.scalars(
        select(Asset).where(Asset.owner_id == owner.id).order_by(Asset.created_at.desc())
    )
    return [await asset_out(session, a, owner) for a in rows]


async def get_asset(session: AsyncSession, asset_id: uuid.UUID, viewer: AccountContext) -> AssetOut:
    asset = await session.get(Asset, asset_id)
    if asset is None:
        raise not_found("Asset")
    return await asset_out(session, asset, viewer)
