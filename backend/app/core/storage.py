"""Photo storage. The app PUTs images to presigned URLs and then confirms the
object key with the API; responses carry short-lived presigned GET URLs."""

import asyncio
import uuid
from datetime import timedelta
from functools import lru_cache
from urllib.parse import urlparse

from minio import Minio
from minio.error import S3Error

from app.core.clock import now
from app.core.config import get_settings
from app.core.errors import ApiError

EXTENSIONS = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


@lru_cache
def _internal() -> Minio:
    s = get_settings()
    return Minio(
        s.storage_endpoint,
        access_key=s.storage_access_key,
        secret_key=s.storage_secret_key,
        secure=s.storage_secure,
        region=s.storage_region,
    )


@lru_cache
def _public() -> Minio:
    """Signs URLs for the host phones use. Signing is local; it makes no request."""
    s = get_settings()
    url = urlparse(s.storage_public_url)
    return Minio(
        url.netloc,
        access_key=s.storage_access_key,
        secret_key=s.storage_secret_key,
        secure=url.scheme == "https",
        region=s.storage_region,
    )


def new_key(purpose: str, account_id: uuid.UUID, content_type: str) -> str:
    return f"{purpose}/{account_id}/{uuid.uuid4().hex}.{EXTENSIONS[content_type]}"


def upload_url(key: str, content_type: str) -> tuple[str, dict[str, str], object]:
    minutes = get_settings().upload_url_minutes
    url = _public().presigned_put_object(
        get_settings().storage_bucket, key, expires=timedelta(minutes=minutes)
    )
    return url, {"Content-Type": content_type}, now() + timedelta(minutes=minutes)


def photo_url(key: str | None) -> str | None:
    if not key:
        return None
    return _public().presigned_get_object(
        get_settings().storage_bucket,
        key,
        expires=timedelta(minutes=get_settings().photo_url_minutes),
    )


def require_own_key(key: str, purpose: str, account_id: uuid.UUID) -> None:
    """An upload can only be attached by whoever it was issued to."""
    if not key.startswith(f"{purpose}/{account_id}/") or ".." in key:
        raise ApiError(422, "INVALID_PHOTO", "That photo upload isn't yours")


async def object_exists(key: str) -> bool:
    def stat() -> bool:
        try:
            _internal().stat_object(get_settings().storage_bucket, key)
            return True
        except S3Error:
            return False

    return await asyncio.to_thread(stat)


async def confirm_upload(key: str, purpose: str, account_id: uuid.UUID) -> None:
    require_own_key(key, purpose, account_id)
    if not await object_exists(key):
        raise ApiError(422, "PHOTO_NOT_UPLOADED", "Upload the photo before confirming it")
