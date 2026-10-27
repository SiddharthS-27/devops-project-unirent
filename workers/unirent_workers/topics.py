from functools import lru_cache
from pathlib import Path

import yaml

TOPICS_FILE = Path(__file__).resolve().parent.parent / "topics.yaml"


@lru_cache
def load() -> dict:
    return yaml.safe_load(TOPICS_FILE.read_text())


def base_topics() -> list[str]:
    return [t["name"] for t in load()["topics"]]


def all_topics() -> list[str]:
    """Every topic with its .retry and .dlq companions."""
    return [f"{name}{suffix}" for name in base_topics() for suffix in ("", ".retry", ".dlq")]


def retry_topic(topic: str) -> str:
    return base_of(topic) + ".retry"


def dlq_topic(topic: str) -> str:
    return base_of(topic) + ".dlq"


def base_of(topic: str) -> str:
    for suffix in (".retry", ".dlq"):
        if topic.endswith(suffix):
            return topic[: -len(suffix)]
    return topic
