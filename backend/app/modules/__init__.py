"""Importing this package registers every core model with the metadata."""

from app.core import models  # noqa: F401
from app.modules.devices import models as devices  # noqa: F401
from app.modules.listings import models as listings  # noqa: F401
from app.modules.profiles import models as profiles  # noqa: F401
from app.modules.search import models as search  # noqa: F401
from app.modules.trust import models as trust  # noqa: F401
