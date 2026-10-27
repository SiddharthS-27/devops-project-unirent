from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class WorkerSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="UNIRENT_", extra="ignore")

    environment: str = "dev"
    # The workers connect as their own restricted database user.
    workers_database_url: str = (
        "postgresql+asyncpg://unirent:unirent-dev-password@localhost:5432/unirent"
    )
    migration_database_url: str | None = None
    kafka_bootstrap: str = "localhost:29092"
    api_base_url: str = "http://localhost:8000"
    service_token: str = "dev-service-token"

    relay_interval_seconds: float = 0.5
    relay_batch_size: int = 100

    consumer_attempts: int = 3
    retry_delay_seconds: float = 30.0

    push_mode: str = "log"  # log or fcm
    fcm_project_id: str = "unirent-dev"
    fcm_credentials_file: str | None = None

    metrics_port: int = 9100
    log_level: str = "INFO"


@lru_cache
def get_settings() -> WorkerSettings:
    return WorkerSettings()
