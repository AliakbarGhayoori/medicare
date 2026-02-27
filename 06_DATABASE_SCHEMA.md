# Database Schema — MediCare AI

**Database**: MongoDB (Motor async driver)
**Date**: February 2026
**Naming**: camelCase for all document fields

---

## 1. Schema Philosophy

- **Minimal collections.** Only what Phase 1 needs. No speculative schemas.
- **camelCase fields.** Matches API JSON contracts and iOS models directly. Python uses aliases at the Pydantic boundary.
- **Additive evolution.** New fields are added with defaults. No destructive migrations.
- **Index for read paths.** Only index what we query. No speculative indexes.

---

## 2. Collections

### `users`

Created on first sign-up. One document per Firebase user.

```javascript
{
    _id: ObjectId("65abc001..."),
    firebaseUid: "uid_abc123",          // unique, from Firebase Auth
    email: "margaret@example.com",       // from Firebase Auth
    name: "Margaret",                    // optional, set during onboarding or settings
    preferences: {
        fontSize: "large",               // "regular" | "large" | "extraLarge"
        highContrast: false
    },
    disclaimerAcceptedAt: ISODate("2026-02-20T10:00:00Z"),
    disclaimerVersion: "1.0",
    createdAt: ISODate("2026-02-20T10:00:00Z"),
    updatedAt: ISODate("2026-02-20T10:00:00Z")
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `firebaseUid` | string | Yes | Unique. Primary lookup key. |
| `email` | string | Yes | Unique. From Firebase. |
| `name` | string | No | Display name, user-set. |
| `preferences` | object | Yes | Defaults applied on creation. |
| `preferences.fontSize` | string | Yes | Default: `"large"` |
| `preferences.highContrast` | boolean | Yes | Default: `false` |
| `disclaimerAcceptedAt` | datetime | No | Set when user accepts disclaimer. |
| `disclaimerVersion` | string | No | Version of disclaimer accepted. |
| `createdAt` | datetime | Yes | Set on insert. |
| `updatedAt` | datetime | Yes | Updated on every write. |

### `conversations`

One document per conversation thread. Title auto-generated from first question.

```javascript
{
    _id: ObjectId("65abc002..."),
    firebaseUid: "uid_abc123",
    title: "Dizzy spells when standing",      // auto-generated, first ~50 chars of first question
    messageCount: 4,
    lastMessagePreview: "Based on your symptoms...",  // first ~100 chars of last assistant message
    createdAt: ISODate("2026-02-20T10:00:00Z"),
    updatedAt: ISODate("2026-02-20T10:05:00Z")
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `firebaseUid` | string | Yes | Owner of the conversation. |
| `title` | string | Yes | Auto-generated from first question (truncated to 100 chars). |
| `messageCount` | int | Yes | Incremented on each new message. |
| `lastMessagePreview` | string | Yes | Preview text for conversation list. |
| `createdAt` | datetime | Yes | Set on insert. |
| `updatedAt` | datetime | Yes | Updated on every new message. |

### `messages`

One document per message (user or assistant). Belongs to a conversation.

```javascript
{
    _id: ObjectId("65abc003..."),
    firebaseUid: "uid_abc123",
    conversationId: ObjectId("65abc002..."),
    role: "assistant",                         // "user" | "assistant"
    content: "Based on your symptoms and your current medications, this could be orthostatic hypotension...",
    citations: [
        {
            number: 1,
            title: "Orthostatic Hypotension",
            source: "Mayo Clinic",
            url: "https://www.mayoclinic.org/diseases-conditions/orthostatic-hypotension/...",
            snippet: "A form of low blood pressure that happens when standing up..."
        },
        {
            number: 2,
            title: "Lisinopril Side Effects",
            source: "Cleveland Clinic",
            url: "https://my.clevelandclinic.org/health/drugs/...",
            snippet: "Common side effects include dizziness, especially when standing..."
        }
    ],
    confidence: "high",                        // "high" | "medium" | "low" | null (user messages)
    requiresEmergencyCare: false,
    createdAt: ISODate("2026-02-20T10:00:30Z")
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `firebaseUid` | string | Yes | Denormalized for direct queries by user. |
| `conversationId` | ObjectId | Yes | Reference to conversations._id. |
| `role` | string | Yes | `"user"` or `"assistant"`. |
| `content` | string | Yes | Full message text. |
| `citations` | array | No | Only on assistant messages. Empty array if no citations. |
| `citations[].number` | int | Yes | Matches inline [N] reference. |
| `citations[].title` | string | Yes | Article/page title. |
| `citations[].source` | string | Yes | Publisher name (Mayo Clinic, NIH, etc.). |
| `citations[].url` | string | Yes | Full URL to source. |
| `citations[].snippet` | string | No | Relevant excerpt from source. |
| `confidence` | string | No | Only on assistant messages. |
| `requiresEmergencyCare` | boolean | No | Only on assistant messages. Default false. |
| `createdAt` | datetime | Yes | Set on insert. |

### `v10Memories`

One document per user. Stores the health profile digest.

```javascript
{
    _id: ObjectId("65abc004..."),
    firebaseUid: "uid_abc123",
    digest: "Conditions: Hypertension (diagnosed 2019), Type 2 Diabetes (diagnosed 2021)\nMedications: Lisinopril 10mg daily, Metformin 500mg twice daily\nAllergies: Penicillin (rash)\nDemographics: 73-year-old female\nRecent Symptoms: Dizzy spells when standing (reported Feb 2026)",
    version: 3,
    lastUpdateSource: "auto",          // "manual" | "auto"
    previousDigest: "...",             // for undo/review of auto-updates
    createdAt: ISODate("2026-02-20T10:00:00Z"),
    updatedAt: ISODate("2026-02-20T10:05:00Z")
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `firebaseUid` | string | Yes | Unique. One digest per user. |
| `digest` | string | Yes | Free-text health profile. |
| `version` | int | Yes | Incremented on every update. |
| `lastUpdateSource` | string | Yes | `"manual"` (user edit) or `"auto"` (AI update). |
| `previousDigest` | string | No | Previous version for undo. Only stores last version. |
| `createdAt` | datetime | Yes | Set on first insert. |
| `updatedAt` | datetime | Yes | Updated on every write. |

---

## 3. Indexes

```python
# src/db/indexes.py
from motor.motor_asyncio import AsyncIOMotorDatabase


async def ensure_indexes(db: AsyncIOMotorDatabase):
    """Create indexes on startup. Idempotent — safe to run repeatedly."""

    # users: lookup by Firebase UID (primary access pattern)
    await db.users.create_index("firebaseUid", unique=True)
    # users: lookup by email (for admin/support, unique constraint)
    await db.users.create_index("email", unique=True)

    # conversations: list user's conversations sorted by most recent
    await db.conversations.create_index(
        [("firebaseUid", 1), ("updatedAt", -1)]
    )

    # messages: load messages for a specific conversation in order
    await db.messages.create_index(
        [("conversationId", 1), ("createdAt", 1)]
    )
    # messages: load all user messages (for account deletion)
    await db.messages.create_index("firebaseUid")

    # v10Memories: one per user
    await db.v10Memories.create_index("firebaseUid", unique=True)
```

### Index Rationale

| Index | Supports Query | Expected Query Pattern |
|-------|---------------|----------------------|
| `users.firebaseUid` (unique) | Find user by UID on every authenticated request | Every API call |
| `users.email` (unique) | Uniqueness constraint + admin lookup | Sign-up, admin |
| `conversations.(firebaseUid, updatedAt)` | List user's conversations, newest first | Conversation list screen |
| `messages.(conversationId, createdAt)` | Load conversation messages in order | Chat thread view |
| `messages.firebaseUid` | Delete all user messages on account deletion | Account deletion |
| `v10Memories.firebaseUid` (unique) | Load/update user's health digest | Every chat request + V10 screen |

---

## 4. MongoDB Connection

```python
# src/db/mongo.py
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from src.config import settings

_client: AsyncIOMotorClient | None = None


def get_client() -> AsyncIOMotorClient:
    """Get or create the Motor client singleton."""
    global _client
    if _client is None:
        _client = AsyncIOMotorClient(
            settings.mongodb_uri,
            maxPoolSize=20,
            minPoolSize=5,
            serverSelectionTimeoutMS=5000,
        )
    return _client


def get_db() -> AsyncIOMotorDatabase:
    """Get the application database."""
    return get_client()[settings.mongodb_database]
```

---

## 5. Service Layer Examples

```python
# src/services/chat_service.py
from bson import ObjectId
from datetime import datetime, timezone
from motor.motor_asyncio import AsyncIOMotorDatabase


def _now() -> datetime:
    return datetime.now(timezone.utc)


async def create_conversation(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    first_question: str,
) -> str:
    """Create a new conversation and return its ID."""
    result = await db.conversations.insert_one({
        "firebaseUid": firebase_uid,
        "title": first_question[:100].strip(),
        "messageCount": 0,
        "lastMessagePreview": "",
        "createdAt": _now(),
        "updatedAt": _now(),
    })
    return str(result.inserted_id)


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
    """Save a message and update the conversation."""
    message = {
        "firebaseUid": firebase_uid,
        "conversationId": ObjectId(conversation_id),
        "role": role,
        "content": content,
        "createdAt": _now(),
    }

    if role == "assistant":
        message["citations"] = citations or []
        message["confidence"] = confidence
        message["requiresEmergencyCare"] = requires_emergency_care

    result = await db.messages.insert_one(message)

    # Update conversation metadata
    preview = content[:100].strip() if role == "assistant" else ""
    update_fields = {"updatedAt": _now()}
    if preview:
        update_fields["lastMessagePreview"] = preview

    await db.conversations.update_one(
        {"_id": ObjectId(conversation_id)},
        {
            "$set": update_fields,
            "$inc": {"messageCount": 1},
        },
    )

    return str(result.inserted_id)


async def get_conversation_messages(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    conversation_id: str,
    limit: int = 50,
    before_id: str | None = None,
) -> list[dict]:
    """Get messages for a conversation, ordered by creation time."""
    query = {
        "conversationId": ObjectId(conversation_id),
        "firebaseUid": firebase_uid,  # Security: ensure user owns this conversation
    }

    if before_id:
        query["_id"] = {"$lt": ObjectId(before_id)}

    cursor = db.messages.find(query).sort("createdAt", 1).limit(limit)
    messages = []

    async for doc in cursor:
        doc["id"] = str(doc.pop("_id"))
        doc["conversationId"] = str(doc["conversationId"])
        messages.append(doc)

    return messages


async def get_user_conversations(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    limit: int = 20,
    before_id: str | None = None,
) -> tuple[list[dict], bool]:
    """Get user's conversations sorted by most recent. Returns (conversations, has_more)."""
    query = {"firebaseUid": firebase_uid}

    if before_id:
        query["_id"] = {"$lt": ObjectId(before_id)}

    cursor = (
        db.conversations.find(query)
        .sort("updatedAt", -1)
        .limit(limit + 1)  # Fetch one extra to check hasMore
    )

    conversations = []
    async for doc in cursor:
        doc["id"] = str(doc.pop("_id"))
        conversations.append(doc)

    has_more = len(conversations) > limit
    if has_more:
        conversations = conversations[:limit]

    return conversations, has_more
```

```python
# src/services/profile_service.py
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime, timezone


def _now() -> datetime:
    return datetime.now(timezone.utc)


async def get_v10_digest(db: AsyncIOMotorDatabase, firebase_uid: str) -> dict | None:
    """Get user's V10 digest."""
    return await db.v10Memories.find_one({"firebaseUid": firebase_uid})


async def upsert_v10_digest(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    digest: str,
    source: str = "manual",
) -> dict:
    """Create or update V10 digest. Returns the updated document."""
    # Get current to preserve previousDigest for undo
    current = await get_v10_digest(db, firebase_uid)
    previous_digest = current["digest"] if current else None

    result = await db.v10Memories.find_one_and_update(
        {"firebaseUid": firebase_uid},
        {
            "$set": {
                "digest": digest,
                "lastUpdateSource": source,
                "previousDigest": previous_digest,
                "updatedAt": _now(),
            },
            "$inc": {"version": 1},
            "$setOnInsert": {
                "firebaseUid": firebase_uid,
                "createdAt": _now(),
            },
        },
        upsert=True,
        return_document=True,
    )
    return result
```

---

## 6. Account Deletion

```python
# src/services/account_service.py
from motor.motor_asyncio import AsyncIOMotorDatabase
from firebase_admin import auth


async def delete_user_account(db: AsyncIOMotorDatabase, firebase_uid: str):
    """Delete all user data across all collections + Firebase Auth."""
    # Delete in order: messages → conversations → v10 → user → firebase
    await db.messages.delete_many({"firebaseUid": firebase_uid})
    await db.conversations.delete_many({"firebaseUid": firebase_uid})
    await db.v10Memories.delete_one({"firebaseUid": firebase_uid})
    await db.users.delete_one({"firebaseUid": firebase_uid})

    # Delete Firebase Auth account
    try:
        auth.delete_user(firebase_uid)
    except auth.UserNotFoundError:
        pass  # Already deleted from Firebase
```

---

## 7. Data Retention & Backup

### Retention Policy (Phase 1)
- All data retained until user deletes their account.
- No automatic data expiration.
- Consider adding conversation archival (auto-archive after 12 months) in Phase 2.

### Backup Strategy
- **MongoDB Atlas**: Automated daily snapshots with point-in-time recovery.
- **Local dev**: No automated backups needed.
- **Manual exports**: `mongodump` for ad-hoc backups before major migrations.

### Schema Migration Strategy
- MongoDB is schema-less — new fields are added with code-level defaults.
- Pydantic models define defaults for fields that may not exist in older documents.
- No migration scripts needed for additive changes.
- For breaking changes: write a one-time migration script, test against a snapshot, then run in production.
