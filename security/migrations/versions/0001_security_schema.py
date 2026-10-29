"""security schema: accounts, staff credentials, refresh tokens, audit log

Revision ID: s0001
Revises:
Create Date: 2026-10-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "s0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

S = "security"


def upgrade() -> None:
    op.create_table(
        "accounts",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False, unique=True),
        sa.Column("role", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("status_reason", sa.Text()),
        sa.Column("display_name", sa.String(200)),
        sa.Column("ms_oid", sa.String(64), unique=True),
        sa.Column("phone", sa.String(20), unique=True),
        sa.Column("phone_verified_at", sa.DateTime(timezone=True)),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("role IN ('student', 'moderator', 'admin')", name="role"),
        sa.CheckConstraint(
            "status IN ('active', 'suspended', 'banned', 'deactivated')", name="status"
        ),
        schema=S,
    )
    op.create_table(
        "staff_credentials",
        sa.Column(
            "account_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{S}.accounts.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("must_change_password", sa.Boolean(), nullable=False),
        sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(timezone=True)),
        sa.Column("password_changed_at", sa.DateTime(timezone=True)),
        schema=S,
    )
    op.create_table(
        "refresh_tokens",
        sa.Column("id", postgresql.UUID(), primary_key=True),
        sa.Column(
            "account_id",
            postgresql.UUID(),
            sa.ForeignKey(f"{S}.accounts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("family_id", postgresql.UUID(), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("issued_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True)),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
        sa.Column("replaced_by", postgresql.UUID()),
        schema=S,
    )
    op.create_index("ix_refresh_tokens_account_id", "refresh_tokens", ["account_id"], schema=S)
    op.create_index("ix_refresh_tokens_family_id", "refresh_tokens", ["family_id"], schema=S)
    op.create_table(
        "audit_log",
        sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("actor_id", postgresql.UUID()),
        sa.Column("actor_role", sa.String(20)),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("target", sa.String(200)),
        sa.Column("details", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("ip", postgresql.INET()),
        schema=S,
    )
    op.create_index("ix_audit_log_actor_id", "audit_log", ["actor_id"], schema=S)
    op.create_index("ix_audit_log_action", "audit_log", ["action"], schema=S)
    op.create_index("ix_audit_log_target", "audit_log", ["target"], schema=S)

    # The audit log is append only, whatever role connects.
    op.execute(
        """
        CREATE FUNCTION security.refuse_change() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          RAISE EXCEPTION '% is append only', TG_TABLE_NAME;
        END $$;
        """
    )
    op.execute(
        "CREATE TRIGGER audit_log_append_only BEFORE UPDATE OR DELETE ON security.audit_log "
        "FOR EACH ROW EXECUTE FUNCTION security.refuse_change()"
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'unirent_app') THEN
            REVOKE UPDATE, DELETE, TRUNCATE ON security.audit_log FROM unirent_app;
          END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.drop_table("audit_log", schema=S)
    op.execute("DROP FUNCTION IF EXISTS security.refuse_change()")
    op.drop_table("refresh_tokens", schema=S)
    op.drop_table("staff_credentials", schema=S)
    op.drop_table("accounts", schema=S)
