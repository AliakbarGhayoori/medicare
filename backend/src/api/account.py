from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.dependencies.auth import AuthUser, get_current_user
from src.dependencies.database import get_db
from src.exceptions import APIError
from src.models.account import DeleteAccountRequest, DeleteAccountResponse
from src.services.account_service import delete_user_account
from src.services.analytics import track_event

router = APIRouter()


@router.delete("", response_model=DeleteAccountResponse)
async def delete_account(
    payload: DeleteAccountRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> DeleteAccountResponse:
    if payload.confirmation != "DELETE":
        raise APIError(422, "VALIDATION_ERROR", "Confirmation must be exactly 'DELETE'.")

    await track_event(
        db,
        "account_delete_requested",
        user.uid,
        {"confirmationMatched": True},
    )
    await delete_user_account(db, firebase_uid=user.uid)
    return DeleteAccountResponse()
