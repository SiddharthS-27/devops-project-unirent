import uuid

from pydantic import BaseModel, EmailStr, Field


class AccountOut(BaseModel):
    id: uuid.UUID
    email: str
    role: str
    status: str
    must_change_password: bool = False


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access token lifetime in seconds")
    account: AccountOut


class MicrosoftSignIn(BaseModel):
    id_token: str = Field(min_length=10)


class MockTokenRequest(BaseModel):
    email: EmailStr
    name: str | None = None


class MockTokenOut(BaseModel):
    id_token: str


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)
