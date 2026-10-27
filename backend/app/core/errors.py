"""The one error shape every endpoint returns: {"error": {"code", "message"}}."""

import logging
from http import HTTPStatus
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

log = logging.getLogger(__name__)


class ApiError(Exception):
    """Raise to return a stable error code the app can switch on."""

    def __init__(
        self, status_code: int, code: str, message: str, details: dict[str, Any] | None = None
    ):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def not_found(what: str = "Resource") -> ApiError:
    return ApiError(404, "NOT_FOUND", f"{what} not found")


def error_body(code: str, message: str, details: Any = None) -> dict[str, Any]:
    error: dict[str, Any] = {"code": code, "message": message}
    if details:
        error["details"] = details
    return {"error": error}


def _code_for_status(status: int) -> str:
    try:
        return HTTPStatus(status).phrase.upper().replace(" ", "_").replace("-", "_")
    except ValueError:
        return "ERROR"


async def _api_error(_: Request, exc: Exception) -> JSONResponse:
    status = getattr(exc, "status_code", 400)
    body = error_body(exc.code, exc.message, getattr(exc, "details", None))  # type: ignore[attr-defined]
    headers = getattr(exc, "headers", None)
    return JSONResponse(body, status_code=status, headers=headers)


async def _http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    message = exc.detail if isinstance(exc.detail, str) else HTTPStatus(exc.status_code).phrase
    return JSONResponse(
        error_body(_code_for_status(exc.status_code), message),
        status_code=exc.status_code,
        headers=getattr(exc, "headers", None),
    )


async def _validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
    details = [
        {"field": ".".join(str(p) for p in err["loc"][1:]), "message": err["msg"]}
        for err in exc.errors()
    ]
    return JSONResponse(
        error_body("VALIDATION_ERROR", "The request is not valid", details), status_code=422
    )


async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
    log.exception("unhandled error", exc_info=exc)
    return JSONResponse(error_body("INTERNAL_ERROR", "Something went wrong"), status_code=500)


def register_error_handlers(app: FastAPI, *error_types: type[Exception]) -> None:
    """Register the handlers. `error_types` are other packages' ApiError classes,
    which carry the same status_code, code and message attributes."""
    for error_type in (ApiError, *error_types):
        app.add_exception_handler(error_type, _api_error)
    app.add_exception_handler(StarletteHTTPException, _http_error)
    app.add_exception_handler(RequestValidationError, _validation_error)
    app.add_exception_handler(Exception, _unhandled)
