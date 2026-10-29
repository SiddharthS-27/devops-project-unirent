from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class PaymentSettings(BaseSettings):
    """Read from UNIRENT_* environment variables, shared with the backend."""

    model_config = SettingsConfigDict(env_prefix="UNIRENT_", extra="ignore")

    environment: str = "dev"
    database_url: str = "postgresql+asyncpg://unirent:unirent-dev-password@localhost:5432/unirent"
    migration_database_url: str | None = None
    redis_url: str = "redis://localhost:6379/0"

    # Razorpay test mode by default. Point the base URL at the simulator without keys.
    razorpay_api_base: str = "https://api.razorpay.com"
    razorpay_key_id: str = "rzp_test_sim"
    razorpay_key_secret: str = "sim-key-secret"
    razorpay_webhook_secret: str = "sim-webhook-secret"
    razorpay_timeout_seconds: float = 10.0

    checkout_name: str = "UniRent"
    idempotency_ttl_hours: int = 24


@lru_cache
def get_settings() -> PaymentSettings:
    return PaymentSettings()
