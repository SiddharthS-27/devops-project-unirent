"""Every router, mounted under /api/v1."""

from fastapi import APIRouter, Depends
from unirent_security.api import admin_router as moderators_router
from unirent_security.api import auth_router

from app.core.clock import now
from app.core.deps import default_rate_limit
from app.core.schemas import ServerTime
from app.modules.admin.router import router as admin_router
from app.modules.bookings.router import router as bookings_router
from app.modules.devices.router import router as devices_router
from app.modules.help.router import router as help_router
from app.modules.listings.router import router as listings_router
from app.modules.profiles.router import router as profiles_router
from app.modules.reviews.router import router as reviews_router
from app.modules.search.router import router as search_router
from app.modules.staff.router import admin_router as staff_admin_router
from app.modules.staff.router import router as staff_router

api_router = APIRouter(prefix="/api/v1")

# Sign-in routes carry their own, stricter limits.
api_router.include_router(auth_router)

limited = APIRouter(dependencies=[Depends(default_rate_limit)])
for router in (
    profiles_router,
    devices_router,
    listings_router,
    search_router,
    bookings_router,
    reviews_router,
    help_router,
    staff_router,
    staff_admin_router,
    admin_router,
    moderators_router,
):
    limited.include_router(router)


@limited.get("/time", response_model=ServerTime, tags=["health"])
async def server_time() -> ServerTime:
    """The server clock. Countdowns use it so phones with a wrong clock still agree."""
    return ServerTime(now=now())


api_router.include_router(limited)
