"""Every router, mounted under /api/v1."""

from fastapi import APIRouter, Depends
from unirent_security.api import admin_router as moderators_router
from unirent_security.api import auth_router

from app.core.deps import default_rate_limit

api_router = APIRouter(prefix="/api/v1")

# Sign-in routes carry their own, stricter limits.
api_router.include_router(auth_router)

limited = APIRouter(dependencies=[Depends(default_rate_limit)])
limited.include_router(moderators_router)

api_router.include_router(limited)
