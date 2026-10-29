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

    @property
    def is_production_like(self) -> bool:
        return self.environment in ("staging", "production")


@lru_cache
def get_settings() -> Settings:
    return Settings()
