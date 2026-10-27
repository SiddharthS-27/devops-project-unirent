from typing import Literal

from pydantic import BaseModel, Field


class PushTokenIn(BaseModel):
    token: str = Field(min_length=10, max_length=500)
    platform: Literal["android", "ios"]


class PushTokensOut(BaseModel):
    tokens: list[str]
