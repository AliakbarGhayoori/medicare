from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase

from src.config import get_settings

logger = logging.getLogger(__name__)


async def track_event(
    db: AsyncIOMotorDatabase | None,
    event: str,
    firebase_uid: str | None,
    properties: dict[str, Any] | None = None,
) -> None:
    settings = get_settings()
    if not settings.analytics_enabled:
        return

    safe_properties = _sanitize_properties(properties or {})

    logger.info(
        "analytics_event",
        extra={
            "event": event,
            "uid_present": bool(firebase_uid),
            "properties": safe_properties,
        },
    )

    if settings.analytics_store_db and db is not None:
        await db.analyticsEvents.insert_one(
            {
                "event": event,
                "firebaseUid": firebase_uid,
                "properties": safe_properties,
                "createdAt": datetime.now(UTC),
            }
        )


def _sanitize_properties(properties: dict[str, Any]) -> dict[str, Any]:
    sanitized: dict[str, Any] = {}

    for key, value in properties.items():
        # Never persist large free-text fields to avoid PHI leakage.
        if any(
            token in key.lower() for token in ("content", "text", "question", "response", "digest")
        ):
            continue

        if isinstance(value, (str, int, float, bool)) or value is None:
            sanitized[key] = value
        elif isinstance(value, list):
            sanitized[key] = [item for item in value if isinstance(item, (str, int, float, bool))][
                :20
            ]
        elif isinstance(value, dict):
            sanitized[key] = {
                k: v for k, v in value.items() if isinstance(v, (str, int, float, bool))
            }

    return sanitized
