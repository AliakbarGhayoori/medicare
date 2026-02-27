from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from src.exceptions import APIError
from src.models.common import ErrorDetail, ErrorResponse

logger = logging.getLogger(__name__)


def _error_payload(code: str, message: str, details: dict | None = None) -> dict:
    payload = ErrorResponse(
        error=ErrorDetail(code=code, message=message, details=details or {}),
    )
    return payload.model_dump()


def _request_id_headers(request: Request) -> dict[str, str]:
    request_id = getattr(request.state, "request_id", None)
    if request_id:
        return {"X-Request-ID": str(request_id)}
    return {}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(APIError)
    async def api_error_handler(request: Request, exc: APIError) -> JSONResponse:
        headers = _request_id_headers(request)
        headers.update(exc.headers)
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_payload(exc.code, exc.message, exc.details),
            headers=headers,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: Request,
        exc: RequestValidationError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content=_error_payload(
                "VALIDATION_ERROR",
                "Request validation failed.",
                {"errors": exc.errors()},
            ),
            headers=_request_id_headers(request),
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        if exc.status_code == 404:
            return JSONResponse(
                status_code=404,
                content=_error_payload("NOT_FOUND", "Requested resource was not found."),
                headers=_request_id_headers(request),
            )
        if exc.status_code == 401:
            return JSONResponse(
                status_code=401,
                content=_error_payload("UNAUTHORIZED", "Authentication is required."),
                headers=_request_id_headers(request),
            )
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_payload("INTERNAL_ERROR", str(exc.detail)),
            headers=_request_id_headers(request),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
        request_id = getattr(request.state, "request_id", None)
        logger.exception(
            "Unhandled server exception: %s",
            exc.__class__.__name__,
            extra={"request_id": request_id} if request_id else None,
        )
        return JSONResponse(
            status_code=500,
            content=_error_payload("INTERNAL_ERROR", "Unexpected server error."),
            headers=_request_id_headers(request),
        )
