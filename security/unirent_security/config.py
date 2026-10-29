from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class SecuritySettings(BaseSettings):
    """Read from UNIRENT_* environment variables, shared with the backend."""

    model_config = SettingsConfigDict(env_prefix="UNIRENT_", extra="ignore")

    environment: str = "dev"
    database_url: str = "postgresql+asyncpg://unirent:unirent-dev-password@localhost:5432/unirent"
    migration_database_url: str | None = None
    redis_url: str = "redis://localhost:6379/0"

    # UniRent's own tokens
    jwt_secret: str = "dev-only-jwt-secret-change-me-0123456789"
    jwt_issuer: str = "unirent"
    access_token_ttl_seconds: int = 15 * 60
    refresh_token_ttl_days: int = 30

    # Microsoft Entra ID sign-in for students
    ms_auth_mode: str = "microsoft"  # microsoft or mock
    ms_client_id: str = "mock-client"
    ms_tenant_id: str = "mock-tenant"
    ms_allowed_domain: str = "college.edu"

    # Firebase phone verification
    phone_auth_mode: str = "firebase"  # firebase or mock
    firebase_project_id: str = "unirent-dev"

    # Signs the mock ID tokens in mock modes. Never used in staging or production.
    mock_token_secret: str = "dev-only-mock-token-secret-0123456789"

    # Staff lockout
    staff_max_failed_logins: int = 5
    staff_lockout_minutes: int = 15

    @property
    def is_production_like(self) -> bool:
        return self.environment in ("staging", "production")

    def mock_allowed(self) -> bool:
        return not self.is_production_like


@lru_cache
def get_settings() -> SecuritySettings:
    return SecuritySettings()
