from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Backend settings, read from UNIRENT_* environment variables."""

    model_config = SettingsConfigDict(env_prefix="UNIRENT_", extra="ignore")

    environment: str = "dev"  # dev, test, staging or production
    database_url: str = "postgresql+asyncpg://unirent:unirent-dev-password@localhost:5432/unirent"
    # Migrations run as the schema owner; the app runs as a restricted user.
    migration_database_url: str | None = None
    redis_url: str = "redis://localhost:6379/0"
    db_pool_size: int = 10
    log_level: str = "INFO"
    # Shared secret the workers send in X-Service-Token on /internal routes.
    service_token: str = "dev-service-token"

    # Photo storage (MinIO, S3 compatible). The app uploads straight to it with
    # presigned URLs, so those are signed for the address phones can reach.
    storage_endpoint: str = "localhost:9000"
    storage_public_url: str = "http://localhost:9000"
    storage_access_key: str = "unirent"
    storage_secret_key: str = "unirent-dev-password"
    storage_bucket: str = "photos"
    storage_secure: bool = False
    storage_region: str = "us-east-1"
    # Trust score weights (the plan's proposal; tune without code changes).
    trust_lender_r: float = 0.70
    trust_lender_c: float = 0.15
    trust_lender_a: float = 0.15
    trust_renter_r: float = 0.50
    trust_renter_p: float = 0.20
    trust_renter_d: float = 0.10
    trust_renter_c: float = 0.10
    trust_renter_a: float = 0.10

    upload_url_minutes: int = 15
    photo_url_minutes: int = 60

    @property
    def is_production_like(self) -> bool:
        return self.environment in ("staging", "production")


@lru_cache
def get_settings() -> Settings:
    return Settings()
