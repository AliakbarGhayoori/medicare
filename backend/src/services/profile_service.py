from __future__ import annotations

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ReturnDocument

from src.utils import utcnow


async def get_v10_digest(db: AsyncIOMotorDatabase, firebase_uid: str) -> dict | None:
    return await db.v10Memories.find_one({"firebaseUid": firebase_uid})


async def upsert_v10_digest(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    digest: str,
    source: str = "manual",
) -> dict:
    existing = await get_v10_digest(db, firebase_uid)
    previous_digest = existing.get("digest") if existing else None

    now = utcnow()
    result = await db.v10Memories.find_one_and_update(
        {"firebaseUid": firebase_uid},
        {
            "$set": {
                "digest": digest,
                "lastUpdateSource": source,
                "previousDigest": previous_digest,
                "updatedAt": now,
            },
            "$inc": {"version": 1},
            "$setOnInsert": {
                "firebaseUid": firebase_uid,
                "createdAt": now,
            },
        },
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )

    if result is None:
        # Defensive fallback for driver edge-cases.
        result = await db.v10Memories.find_one({"firebaseUid": firebase_uid})
    return result or {}


async def revert_v10_digest(db: AsyncIOMotorDatabase, firebase_uid: str) -> dict | None:
    current = await get_v10_digest(db, firebase_uid)
    if not current:
        return None

    previous_digest = current.get("previousDigest")
    if not previous_digest:
        return current

    now = utcnow()
    result = await db.v10Memories.find_one_and_update(
        {"firebaseUid": firebase_uid},
        {
            "$set": {
                "digest": previous_digest,
                "previousDigest": current.get("digest"),
                "lastUpdateSource": "manual",
                "updatedAt": now,
            },
            "$inc": {"version": 1},
        },
        return_document=ReturnDocument.AFTER,
    )

    if result is None:
        return await get_v10_digest(db, firebase_uid)
    return result
