from typing import Any


class ApiError(Exception):
    """An error with a stable code. The backend renders it as
    {"error": {"code": ..., "message": ...}}."""

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        details: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details
        self.headers = headers


def unauthenticated(code: str = "UNAUTHENTICATED", message: str = "Sign in again") -> ApiError:
    return ApiError(401, code, message, headers={"WWW-Authenticate": "Bearer"})


def forbidden(code: str = "FORBIDDEN", message: str = "You can't do that") -> ApiError:
    return ApiError(403, code, message)


def not_found(what: str = "Resource") -> ApiError:
    return ApiError(404, "NOT_FOUND", f"{what} not found")
