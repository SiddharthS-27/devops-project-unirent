"""JSON-lines logs, like the api's, so Promtail ships both the same way."""

import json
import logging
import sys
from datetime import UTC, datetime

_RESERVED = set(logging.makeLogRecord({}).__dict__) | {"message", "asctime"}


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "ts": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname.lower(),
            "logger": record.name,
            "message": record.getMessage(),
            "service": "workers",
        }
        entry.update(
            {
                k: v
                for k, v in record.__dict__.items()
                if k not in _RESERVED and not k.startswith("_")
            }
        )
        if record.exc_info:
            entry["exc"] = self.formatException(record.exc_info)
        return json.dumps(entry, default=str)


def configure(level: str) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    logging.getLogger().handlers[:] = [handler]
    logging.getLogger().setLevel(level)
    logging.getLogger("aiokafka").setLevel("WARNING")
