import json

from aiokafka import AIOKafkaProducer

from unirent_workers.config import get_settings


def encode(value: dict) -> bytes:
    return json.dumps(value, separators=(",", ":"), default=str).encode()


async def start_producer() -> AIOKafkaProducer:
    """Idempotent producer that waits for the broker to acknowledge every send."""
    producer = AIOKafkaProducer(
        bootstrap_servers=get_settings().kafka_bootstrap,
        acks="all",
        enable_idempotence=True,
        linger_ms=5,
    )
    await producer.start()
    return producer
