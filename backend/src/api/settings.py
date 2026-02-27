from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.dependencies.auth import AuthUser, get_current_user
from src.dependencies.database import get_db
from src.models.settings import (
    AcceptDisclaimerRequest,
    AcceptDisclaimerResponse,
    SettingsResponse,
    SettingsUpdate,
)
from src.services.analytics import track_event
from src.services.settings_service import (
    accept_disclaimer,
    get_settings_document,
    resolved_disclaimer_version,
    update_settings_document,
)

router = APIRouter()


@router.get("", response_model=SettingsResponse)
async def get_settings(
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> SettingsResponse:
    settings_doc = await get_settings_document(db, firebase_uid=user.uid, email=user.email)
    return SettingsResponse(**settings_doc)


@router.put("", response_model=SettingsResponse)
async def put_settings(
    payload: SettingsUpdate,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> SettingsResponse:
    changed_fields: list[str] = []
    if payload.font_size is not None:
        changed_fields.append("fontSize")
    if payload.high_contrast is not None:
        changed_fields.append("highContrast")

    updated = await update_settings_document(
        db=db,
        firebase_uid=user.uid,
        email=user.email,
        font_size=payload.font_size.value if payload.font_size is not None else None,
        high_contrast=payload.high_contrast,
    )

    if changed_fields:
        await track_event(
            db,
            "settings_changed",
            user.uid,
            {"changedFields": changed_fields},
        )

    return SettingsResponse(**updated)


@router.post("/accept-disclaimer", response_model=AcceptDisclaimerResponse)
async def post_accept_disclaimer(
    payload: AcceptDisclaimerRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> AcceptDisclaimerResponse:
    version = resolved_disclaimer_version(payload.disclaimer_version)
    response = await accept_disclaimer(
        db=db,
        firebase_uid=user.uid,
        email=user.email,
        disclaimer_version=version,
    )
    await track_event(
        db,
        "onboarding_completed",
        user.uid,
        {"disclaimerVersion": version},
    )
    return AcceptDisclaimerResponse(**response)
