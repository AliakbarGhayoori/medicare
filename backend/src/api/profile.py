from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.config import get_settings
from src.dependencies.auth import AuthUser, get_current_user
from src.dependencies.database import get_db
from src.exceptions import APIError
from src.models.profile import V10DigestResponse, V10DigestUpdate
from src.services.analytics import track_event
from src.services.profile_service import get_v10_digest, revert_v10_digest, upsert_v10_digest
from src.services.rate_limiter import check_rate_limit_with_retry
from src.services.settings_service import ensure_user_document

router = APIRouter()


@router.get("/v10", response_model=V10DigestResponse)
async def get_v10(
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> V10DigestResponse:
    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)
    doc = await get_v10_digest(db, firebase_uid=user.uid)
    if not doc:
        return V10DigestResponse(
            digest=None,
            previousDigest=None,
            canRevert=False,
            version=0,
            updatedAt=None,
            lastUpdateSource=None,
        )

    return V10DigestResponse(
        digest=doc.get("digest"),
        previousDigest=doc.get("previousDigest"),
        canRevert=bool(doc.get("previousDigest")),
        version=doc.get("version", 0),
        updatedAt=doc.get("updatedAt"),
        lastUpdateSource=doc.get("lastUpdateSource"),
    )


@router.put("/v10", response_model=V10DigestResponse)
async def put_v10(
    payload: V10DigestUpdate,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> V10DigestResponse:
    settings = get_settings()
    allowed, retry_after = check_rate_limit_with_retry(
        f"v10:{user.uid}",
        max_requests=settings.v10_rate_limit_per_hour,
        window_seconds=3600,
    )
    if not allowed:
        raise APIError(
            429,
            "RATE_LIMITED",
            "V10 update rate limit exceeded. Please try later.",
            headers={"Retry-After": str(retry_after)},
        )

    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)
    updated = await upsert_v10_digest(
        db=db,
        firebase_uid=user.uid,
        digest=payload.digest,
        source="manual",
    )

    await track_event(
        db,
        "v10_edited",
        user.uid,
        {
            "source": "manual",
            "version": updated.get("version", 0),
        },
    )

    return V10DigestResponse(
        digest=updated.get("digest"),
        previousDigest=updated.get("previousDigest"),
        canRevert=bool(updated.get("previousDigest")),
        version=updated.get("version", 0),
        updatedAt=updated.get("updatedAt"),
        lastUpdateSource=updated.get("lastUpdateSource"),
    )


@router.post("/v10/revert", response_model=V10DigestResponse)
async def revert_v10(
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> V10DigestResponse:
    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)
    updated = await revert_v10_digest(db, firebase_uid=user.uid)

    if updated is None:
        return V10DigestResponse(
            digest=None,
            previousDigest=None,
            canRevert=False,
            version=0,
            updatedAt=None,
            lastUpdateSource=None,
        )

    await track_event(
        db,
        "v10_edited",
        user.uid,
        {
            "source": "revert",
            "version": updated.get("version", 0),
        },
    )

    return V10DigestResponse(
        digest=updated.get("digest"),
        previousDigest=updated.get("previousDigest"),
        canRevert=bool(updated.get("previousDigest")),
        version=updated.get("version", 0),
        updatedAt=updated.get("updatedAt"),
        lastUpdateSource=updated.get("lastUpdateSource"),
    )
