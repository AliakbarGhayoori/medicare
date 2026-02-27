from __future__ import annotations

from motor.motor_asyncio import AsyncIOMotorDatabase


async def ensure_indexes(db: AsyncIOMotorDatabase) -> None:
    await db.users.create_index("firebaseUid", unique=True)
    await db.users.create_index("email", unique=True, sparse=True)

    await db.conversations.create_index([("firebaseUid", 1), ("updatedAt", -1)])

    await db.messages.create_index([("conversationId", 1), ("createdAt", 1)])
    await db.messages.create_index("firebaseUid")

    await db.v10Memories.create_index("firebaseUid", unique=True)

    # analyticsEvents: optional event storage for operational dashboards.
    await db.analyticsEvents.create_index([("firebaseUid", 1), ("createdAt", -1)])
    await db.analyticsEvents.create_index([("event", 1), ("createdAt", -1)])
