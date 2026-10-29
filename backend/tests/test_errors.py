import httpx
from fastapi import FastAPI
from pydantic import BaseModel

from app.core.errors import ApiError, register_error_handlers
from app.core.middleware import RequestContextMiddleware


class Body(BaseModel):
    amount_paise: int


def _app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(RequestContextMiddleware)
    register_error_handlers(app)

    @app.get("/boom")
    async def boom():
        raise ApiError(409, "BOOKING_NOT_APPROVED", "The booking is not approved")

    @app.post("/body")
    async def body(_: Body):
        return {}

    @app.get("/crash")
    async def crash():
        raise RuntimeError("bug")

    return app


async def _call(method: str, path: str, **kwargs) -> httpx.Response:
    transport = httpx.ASGITransport(app=_app(), raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
        return await c.request(method, path, **kwargs)


async def test_api_error_uses_the_standard_shape():
    r = await _call("GET", "/boom")
    assert r.status_code == 409
    assert r.json() == {
        "error": {"code": "BOOKING_NOT_APPROVED", "message": "The booking is not approved"}
    }


async def test_unknown_route_is_not_found():
    r = await _call("GET", "/nope")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "NOT_FOUND"


async def test_validation_errors_list_the_fields():
    r = await _call("POST", "/body", json={"amount_paise": "lots"})
    assert r.status_code == 422
    error = r.json()["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert error["details"][0]["field"] == "amount_paise"


async def test_unhandled_errors_hide_details():
    r = await _call("GET", "/crash")
    assert r.status_code == 500
    assert r.json() == {"error": {"code": "INTERNAL_ERROR", "message": "Something went wrong"}}


async def test_request_id_is_generated_or_echoed():
    r = await _call("GET", "/boom")
    assert len(r.headers["x-request-id"]) == 32
    r = await _call("GET", "/boom", headers={"X-Request-ID": "abc123"})
    assert r.headers["x-request-id"] == "abc123"


def test_api_logs_are_masked(capsys):
    import logging

    from app.core.logging import configure_logging

    configure_logging("INFO")
    logging.getLogger("t").info("signed in %s", "asha@college.edu", extra={"phone": "9876543210"})
    out = capsys.readouterr().out
    assert "asha@college.edu" not in out and "9876543210" not in out
