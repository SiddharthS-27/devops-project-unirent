"""indexes for the hot queries

Revision ID: 0014
Revises: 0013
Create Date: 2026-10-29

Each matches a query the app runs on every screen load: the Bookings tab
(by side, newest first), incoming requests per listing, a profile's
reviews, the appeals queue and the owner's listings.
"""

from collections.abc import Sequence

from alembic import op

revision: str = "0014"
down_revision: str | None = "0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

INDEXES = [
    ("ix_bookings_renter_updated", "bookings", "renter_id, updated_at DESC"),
    ("ix_bookings_owner_updated", "bookings", "owner_id, updated_at DESC"),
    ("ix_bookings_listing_status", "bookings", "listing_id, status"),
    ("ix_reviews_reviewee_role_created", "reviews", "reviewee_id, reviewee_role, created_at DESC"),
    ("ix_appeals_status_created", "appeals", "status, created_at"),
    ("ix_listings_owner_created", "listings", "owner_id, created_at DESC"),
    ("ix_handover_photos_booking_phase", "handover_photos", "booking_id, phase, side"),
]


def upgrade() -> None:
    for name, table, columns in INDEXES:
        op.execute(f"CREATE INDEX IF NOT EXISTS {name} ON core.{table} ({columns})")
    # Overdue and stalled rentals for the escalations queue.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_bookings_overdue ON core.bookings (overdue_since) "
        "WHERE status = 'overdue'"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_bookings_returning ON core.bookings (return_completed_at) "
        "WHERE status = 'returning'"
    )


def downgrade() -> None:
    for name in [i[0] for i in INDEXES] + ["ix_bookings_overdue", "ix_bookings_returning"]:
        op.execute(f"DROP INDEX IF EXISTS core.{name}")
