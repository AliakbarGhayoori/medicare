from __future__ import annotations

import logging
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from src.api import account, chat, profile, settings
from src.config import get_settings
from src.db.indexes import ensure_indexes
from src.db.mongo import close_mongo_connection, connect_to_mongo, get_database
from src.logging_config import configure_logging
from src.middleware.error_handlers import register_exception_handlers

configure_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings_obj = get_settings()
    if settings_obj.environment != "test":
        await connect_to_mongo()
        db = get_database()
        await ensure_indexes(db)
    try:
        yield
    finally:
        if settings_obj.environment != "test":
            await close_mongo_connection()


def create_app() -> FastAPI:
    settings_obj = get_settings()

    app = FastAPI(title="MediCare AI API", version=settings_obj.api_version, lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings_obj.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
        expose_headers=["X-Request-ID", "Retry-After"],
    )

    register_exception_handlers(app)

    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id

        start = time.monotonic()
        response = await call_next(request)
        latency_ms = int((time.monotonic() - start) * 1000)
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "request_complete",
            extra={
                "method": request.method,
                "endpoint": request.url.path,
                "status_code": response.status_code,
                "latency_ms": latency_ms,
                "request_id": request_id,
            },
        )
        return response

    app.include_router(chat.router, prefix="/api/chat", tags=["chat"])
    app.include_router(profile.router, prefix="/api/profile", tags=["profile"])
    app.include_router(settings.router, prefix="/api/settings", tags=["settings"])
    app.include_router(account.router, prefix="/api/account", tags=["account"])

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "healthy", "version": settings_obj.api_version}

    return app


app = create_app()
