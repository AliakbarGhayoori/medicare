from __future__ import annotations

from bson import ObjectId
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.exceptions import APIError
from src.utils import utcnow


async def create_conversation(
    db: AsyncIOMotorDatabase, firebase_uid: str, first_question: str
) -> str:
    title = first_question.strip()[:100] or "New conversation"
    timestamp = utcnow()
    result = await db.conversations.insert_one(
        {
            "firebaseUid": firebase_uid,
            "title": title,
            "messageCount": 0,
            "lastMessagePreview": "",
            "createdAt": timestamp,
            "updatedAt": timestamp,
        }
    )
    return str(result.inserted_id)


async def conversation_exists_for_user(
    db: AsyncIOMotorDatabase, firebase_uid: str, conversation_id: str
) -> bool:
    doc = await db.conversations.find_one(
        {"_id": ObjectId(conversation_id), "firebaseUid": firebase_uid}, {"_id": 1}
    )
    return doc is not None


async def resolve_conversation_id(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    question: str,
    conversation_id: str | None,
) -> str:
    if conversation_id is None:
        return await create_conversation(db, firebase_uid, question)

    if not await conversation_exists_for_user(db, firebase_uid, conversation_id):
        raise APIError(404, "NOT_FOUND", "Conversation was not found.")
    return conversation_id


async def save_message(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    conversation_id: str,
    role: str,
    content: str,
    citations: list[dict] | None = None,
    confidence: str | None = None,
    requires_emergency_care: bool = False,
) -> str:
    if not ObjectId.is_valid(conversation_id):
        raise APIError(422, "VALIDATION_ERROR", "Invalid conversationId.")

    timestamp = utcnow()
    document: dict = {
        "firebaseUid": firebase_uid,
        "conversationId": ObjectId(conversation_id),
        "role": role,
        "content": content,
        "createdAt": timestamp,
    }

    if role == "assistant":
        document["citations"] = citations or []
        document["confidence"] = confidence
        document["requiresEmergencyCare"] = requires_emergency_care

    result = await db.messages.insert_one(document)

    update_fields: dict[str, object] = {
        "updatedAt": timestamp,
    }
    if role == "assistant":
        update_fields["lastMessagePreview"] = content.strip()[:100]

    await db.conversations.update_one(
        {"_id": ObjectId(conversation_id), "firebaseUid": firebase_uid},
        {
            "$set": update_fields,
            "$inc": {"messageCount": 1},
        },
    )

    return str(result.inserted_id)


async def get_recent_messages_for_context(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    conversation_id: str,
    limit: int,
) -> list[dict]:
    cursor = (
        db.messages.find(
            {
                "firebaseUid": firebase_uid,
                "conversationId": ObjectId(conversation_id),
            },
            {"role": 1, "content": 1},
        )
        .sort([("createdAt", -1), ("_id", -1)])
        .limit(limit)
    )

    docs = [doc async for doc in cursor]
    docs.reverse()
    return docs


async def list_conversations(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    limit: int,
    before: str | None,
) -> tuple[list[dict], bool, str | None]:
    query: dict = {"firebaseUid": firebase_uid}

    if before:
        if not ObjectId.is_valid(before):
            raise APIError(422, "VALIDATION_ERROR", "Invalid before cursor.")
        query["_id"] = {"$lt": ObjectId(before)}

    cursor = db.conversations.find(query).sort("updatedAt", -1).limit(limit + 1)

    rows = [row async for row in cursor]
    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]

    next_cursor = str(rows[-1]["_id"]) if has_more and rows else None

    conversations: list[dict] = []
    for row in rows:
        conversations.append(
            {
                "id": str(row["_id"]),
                "title": row.get("title", "New conversation"),
                "lastMessage": row.get("lastMessagePreview", ""),
                "messageCount": row.get("messageCount", 0),
                "createdAt": row["createdAt"],
                "updatedAt": row["updatedAt"],
            }
        )

    return conversations, has_more, next_cursor


async def list_conversation_messages(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    conversation_id: str,
    limit: int,
    before: str | None,
) -> tuple[list[dict], bool, str | None]:
    if not ObjectId.is_valid(conversation_id):
        raise APIError(422, "VALIDATION_ERROR", "Invalid conversationId.")

    if not await conversation_exists_for_user(db, firebase_uid, conversation_id):
        raise APIError(404, "NOT_FOUND", "Conversation was not found.")

    query: dict = {
        "firebaseUid": firebase_uid,
        "conversationId": ObjectId(conversation_id),
    }

    if before:
        if not ObjectId.is_valid(before):
            raise APIError(422, "VALIDATION_ERROR", "Invalid before cursor.")
        query["_id"] = {"$lt": ObjectId(before)}

    cursor = db.messages.find(query).sort([("createdAt", -1), ("_id", -1)]).limit(limit + 1)
    rows = [row async for row in cursor]

    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]

    rows.reverse()
    next_cursor = str(rows[0]["_id"]) if has_more and rows else None

    messages: list[dict] = []
    for row in rows:
        payload = {
            "id": str(row["_id"]),
            "role": row["role"],
            "content": row["content"],
            "createdAt": row["createdAt"],
            "citations": row.get("citations", []),
            "confidence": row.get("confidence"),
            "requiresEmergencyCare": row.get("requiresEmergencyCare", False),
        }
        messages.append(payload)

    return messages, has_more, next_cursor
