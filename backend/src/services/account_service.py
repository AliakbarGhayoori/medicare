from __future__ import annotations

from firebase_admin import auth
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.config import get_settings


async def delete_user_account(db: AsyncIOMotorDatabase, firebase_uid: str) -> None:
    await db.messages.delete_many({"firebaseUid": firebase_uid})
    await db.conversations.delete_many({"firebaseUid": firebase_uid})
    await db.v10Memories.delete_one({"firebaseUid": firebase_uid})
    await db.analyticsEvents.delete_many({"firebaseUid": firebase_uid})
    await db.users.delete_one({"firebaseUid": firebase_uid})

    if get_settings().auth_mode == "firebase":
        try:
            auth.delete_user(firebase_uid)
        except auth.UserNotFoundError:
            pass
