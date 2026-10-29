import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class ReviewOut(BaseModel):
    id: uuid.UUID
    booking_id: uuid.UUID
    review_type: Literal["renter", "lender", "renter_sale", "lender_sale", "cancellation"]
    overall: float
    ratings: dict[str, int]
    comment: str
    reviewer_id: uuid.UUID
    reviewer_name: str
    created_at: datetime
