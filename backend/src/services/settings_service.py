from __future__ import annotations

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ReturnDocument

from src.config import get_settings
from src.utils import utcnow


def _default_preferences() -> dict:
    return {
        "fontSize": "large",
        "highContrast": False,
    }


async def ensure_user_document(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    email: str | None,
) -> dict:
    now = utcnow()
    await db.users.update_one(
        {"firebaseUid": firebase_uid},
        {
            "$setOnInsert": {
                "firebaseUid": firebase_uid,
                "email": email,
                "preferences": _default_preferences(),
                "createdAt": now,
                "updatedAt": now,
            }
        },
        upsert=True,
    )
    doc = await db.users.find_one({"firebaseUid": firebase_uid})
    return doc or {
        "firebaseUid": firebase_uid,
        "email": email,
        "preferences": _default_preferences(),
    }


async def get_settings_document(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    email: str | None,
) -> dict:
    doc = await ensure_user_document(db, firebase_uid, email)
    prefs = doc.get("preferences") or _default_preferences()

    return {
        "fontSize": prefs.get("fontSize", "large"),
        "highContrast": bool(prefs.get("highContrast", False)),
        "disclaimerAcceptedAt": doc.get("disclaimerAcceptedAt"),
        "disclaimerVersion": doc.get("disclaimerVersion"),
    }


async def update_settings_document(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    email: str | None,
    font_size: str | None,
    high_contrast: bool | None,
) -> dict:
    await ensure_user_document(db, firebase_uid, email)

    set_ops: dict[str, object] = {"updatedAt": utcnow()}
    if font_size is not None:
        set_ops["preferences.fontSize"] = font_size
    if high_contrast is not None:
        set_ops["preferences.highContrast"] = high_contrast

    await db.users.update_one({"firebaseUid": firebase_uid}, {"$set": set_ops})

    return await get_settings_document(db, firebase_uid, email)


async def accept_disclaimer(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    email: str | None,
    disclaimer_version: str,
) -> dict:
    accepted_at = utcnow()

    await ensure_user_document(db, firebase_uid, email)
    updated = await db.users.find_one_and_update(
        {"firebaseUid": firebase_uid},
        {
            "$set": {
                "disclaimerAcceptedAt": accepted_at,
                "disclaimerVersion": disclaimer_version,
                "updatedAt": accepted_at,
            }
        },
        return_document=ReturnDocument.AFTER,
    )

    _ = updated  # keep lint quiet; response uses accepted_at for authoritative timestamp
    return {
        "accepted": True,
        "disclaimerVersion": disclaimer_version,
        "acceptedAt": accepted_at,
    }


def resolved_disclaimer_version(requested_version: str | None) -> str:
    if requested_version:
        return requested_version
    return get_settings().disclaimer_current_version
