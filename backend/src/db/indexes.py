from __future__ import annotations

from motor.motor_asyncio import AsyncIOMotorDatabase

_LEGACY_UNIQUE_EMAIL_INDEX = "email_1"


async def _drop_legacy_unique_email_index(db: AsyncIOMotorDatabase) -> None:
    # Email is not an identity. When a Firebase account is deleted and re-created
    # with the same email it gets a new uid, and the old user record must not
    # block the new one (it made every endpoint fail with DuplicateKeyError).
    legacy = (await db.users.index_information()).get(_LEGACY_UNIQUE_EMAIL_INDEX)
    if legacy and legacy.get("unique"):
        await db.users.drop_index(_LEGACY_UNIQUE_EMAIL_INDEX)


async def ensure_indexes(db: AsyncIOMotorDatabase) -> None:
    await db.users.create_index("firebaseUid", unique=True)
    await _drop_legacy_unique_email_index(db)

    await db.conversations.create_index([("firebaseUid", 1), ("updatedAt", -1)])

    await db.messages.create_index([("conversationId", 1), ("createdAt", 1)])
    await db.messages.create_index("firebaseUid")

    await db.v10Memories.create_index("firebaseUid", unique=True)

    # analyticsEvents: optional event storage for operational dashboards.
    await db.analyticsEvents.create_index([("firebaseUid", 1), ("createdAt", -1)])
    await db.analyticsEvents.create_index([("event", 1), ("createdAt", -1)])
