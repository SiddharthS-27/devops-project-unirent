"""let the workers user read and mark the outbox

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-27
"""

from collections.abc import Sequence

from alembic import op

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # The relay is the one reader of another schema's table (the plan's exception).
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'unirent_workers') THEN
            GRANT SELECT, UPDATE ON core.outbox TO unirent_workers;
          END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'unirent_workers') THEN
            REVOKE SELECT, UPDATE ON core.outbox FROM unirent_workers;
          END IF;
        END $$;
        """
    )
