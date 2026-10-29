"""Importing this package registers every core model with the metadata."""

from app.core import models  # noqa: F401
from app.modules.devices import models as devices  # noqa: F401
from app.modules.profiles import models as profiles  # noqa: F401
