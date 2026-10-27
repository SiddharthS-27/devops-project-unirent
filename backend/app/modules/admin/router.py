import uuid
from typing import Annotated

from fastapi import APIRouter, Query
from unirent_security import AdminAccount

from app.core.deps import SessionDep
from app.core.errors import not_implemented
from app.core.schemas import Page
from app.modules.admin.schemas import AuditEntryOut, ClockIn, ClockOut, MetricsOut

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/metrics", response_model=MetricsOut)
async def metrics(admin: AdminAccount, session: SessionDep):
    raise not_implemented()


@router.get("/audit-log", response_model=Page[AuditEntryOut])
async def audit_log(
    admin: AdminAccount,
    actor_id: uuid.UUID | None = None,
    target: str | None = None,
    cursor: str | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
):
    raise not_implemented()


@router.get("/clock", response_model=ClockOut)
async def get_clock(admin: AdminAccount):
    raise not_implemented()


@router.post("/clock", response_model=ClockOut)
async def set_clock(body: ClockIn, admin: AdminAccount):
    """Staging only: move the clock forward for the demo (for example to an overdue rental)."""
    raise not_implemented()
