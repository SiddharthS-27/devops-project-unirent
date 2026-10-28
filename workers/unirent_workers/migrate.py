"""Run the workers schema's migrations at startup, as the schema owner."""

import logging
from pathlib import Path

from alembic import command
from alembic.config import Config

from unirent_workers.config import get_settings

log = logging.getLogger(__name__)
ROOT = Path(__file__).resolve().parent.parent


def upgrade() -> None:
    if not get_settings().migration_database_url:
        log.info("no migration database url; skipping migrations")
        return
    config = Config(str(ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(ROOT / "migrations"))
    command.upgrade(config, "head")
