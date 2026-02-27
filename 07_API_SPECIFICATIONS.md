# API Specifications — MediCare AI

**Date**: February 2026
**Base URL**: `https://api.medicare-ai.example/` (production) / `http://localhost:8000` (dev)
**Auth**: Firebase ID Token as Bearer token in `Authorization` header
**Format**: JSON (request/response bodies), SSE (streaming chat)

---

## 1. Common Conventions

### Authentication
All endpoints except `/health` require a valid Firebase ID token:
```
Authorization: Bearer <firebase_id_token>
```

### Error Response Envelope
Every error returns this shape:
```json
{
    "error": {
        "code": "ERROR_CODE",
        "message": "Human-readable error message.",
        "details": {}
    }
}
```

### Error Codes Reference
| Code | HTTP Status | Description |
|------|------------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid bearer token |
| `TOKEN_EXPIRED` | 401 | Firebase token has expired (client should refresh and retry) |
| `VALIDATION_ERROR` | 422 | Request body failed validation |
| `NOT_FOUND` | 404 | Requested resource doesn't exist |
| `RATE_LIMITED` | 429 | Too many requests (include `Retry-After` header) |
| `AI_ERROR` | 502 | Anthropic API returned an error |
| `AI_TIMEOUT` | 504 | Anthropic API request timed out |
| `INTERNAL_ERROR` | 500 | Unexpected server error |

### Pagination
List endpoints support cursor-based pagination:
```
GET /api/chat/history?limit=20&before=<conversation_id>
```
- `limit`: Number of items to return (default 20, max 50).
- `before`: Return items created before this ID (for "load more" / infinite scroll).

---

## 2. Health Check

### `GET /health`

No authentication required.

**Response** `200 OK`:
```json
{
    "status": "healthy",
    "version": "3.0"
}
```

---

## 3. Chat Endpoints

### `POST /api/chat/ask`

Ask a health question. Returns a **streaming SSE response**.

**Request Headers**:
```
Authorization: Bearer <token>
Content-Type: application/json
Accept: text/event-stream
```

**Request Body**:
```json
{
    "question": "I've been having dizzy spells when I stand up",
    "conversationId": "65abc123def456..."
}
```

| Field | Type | Required | Validation |
|-------|------|----------|-----------|
| `question` | string | Yes | 1-2000 characters, non-empty after trim |
| `conversationId` | string | No | Valid ObjectId. If omitted, creates a new conversation. |

**Response**: `200 OK` with `Content-Type: text/event-stream`

SSE event stream:
```
event: token
data: {"text": "Based on your "}

event: token
data: {"text": "symptoms and your "}

event: token
data: {"text": "current medications, "}

event: tool_use
data: {"tool": "web_search", "status": "searching"}

event: token
data: {"text": "orthostatic hypotension "}

... (more tokens)

event: done
data: {"messageId": "65abc789...", "conversationId": "65abc123...", "citations": [{"number": 1, "title": "Orthostatic Hypotension", "source": "Mayo Clinic", "url": "https://www.mayoclinic.org/...", "snippet": "A form of low blood pressure..."}], "confidence": "high", "requiresEmergencyCare": false}
```

**SSE Event Types**:
| Event | Data Shape | Description |
|-------|-----------|-------------|
| `token` | `{"text": "..."}` | Incremental text chunk |
| `tool_use` | `{"tool": "web_search", "status": "searching"}` | Model is searching for evidence |
| `done` | `{"messageId", "conversationId", "citations", "confidence", "requiresEmergencyCare"}` | Stream complete with metadata |
| `error` | `{"code": "AI_ERROR", "message": "..."}` | Stream-level error |

**Error Responses**:
| Status | Code | When |
|--------|------|------|
| 401 | `UNAUTHORIZED` | Invalid or missing token |
| 422 | `VALIDATION_ERROR` | Empty question, too long, invalid conversationId |
| 429 | `RATE_LIMITED` | Exceeded 30 requests/hour |
| 502 | `AI_ERROR` | Anthropic API error |
| 504 | `AI_TIMEOUT` | Anthropic API timeout (>30s) |

---

### `GET /api/chat/history`

Get the user's conversation list.

**Request**:
```
GET /api/chat/history?limit=20&before=65abc123...
Authorization: Bearer <token>
```

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `limit` | int | No | 20 | Items per page (1-50) |
| `before` | string | No | — | Cursor: conversations before this ID |

**Response** `200 OK`:
```json
{
    "conversations": [
        {
            "id": "65abc123def456...",
            "title": "Dizzy spells when standing",
            "lastMessage": "Based on your symptoms...",
            "messageCount": 4,
            "createdAt": "2026-02-20T10:00:00Z",
            "updatedAt": "2026-02-20T10:05:00Z"
        }
    ],
    "hasMore": true,
    "nextCursor": "65abc122..."
}
```

---

### `GET /api/chat/history/{conversationId}`

Get messages for a specific conversation.

**Request**:
```
GET /api/chat/history/65abc123...?limit=50&before=<message_id>
Authorization: Bearer <token>
```

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `limit` | int | No | 50 | Messages per page (1-100) |
| `before` | string | No | — | Cursor: messages before this ID |

**Response** `200 OK`:
```json
{
    "conversationId": "65abc123def456...",
    "messages": [
        {
            "id": "65msg001...",
            "role": "user",
            "content": "I've been having dizzy spells when I stand up",
            "createdAt": "2026-02-20T10:00:00Z"
        },
        {
            "id": "65msg002...",
            "role": "assistant",
            "content": "Based on your symptoms and your current medications...",
            "citations": [
                {
                    "number": 1,
                    "title": "Orthostatic Hypotension",
                    "source": "Mayo Clinic",
                    "url": "https://www.mayoclinic.org/...",
                    "snippet": "A form of low blood pressure..."
                }
            ],
            "confidence": "high",
            "requiresEmergencyCare": false,
            "createdAt": "2026-02-20T10:00:30Z"
        }
    ],
    "hasMore": false,
    "nextCursor": null
}
```

**Error Responses**:
| Status | Code | When |
|--------|------|------|
| 401 | `UNAUTHORIZED` | Invalid token |
| 404 | `NOT_FOUND` | Conversation doesn't exist or belongs to another user |

---

## 4. Profile Endpoints

### `GET /api/profile/v10`

Get the user's V10 health digest.

**Response** `200 OK`:
```json
{
    "digest": "Conditions: Hypertension (diagnosed 2019), Type 2 Diabetes (diagnosed 2021)\nMedications: Lisinopril 10mg daily, Metformin 500mg twice daily\nAllergies: Penicillin (rash)\nDemographics: 73-year-old female",
    "version": 3,
    "updatedAt": "2026-02-20T10:05:00Z",
    "lastUpdateSource": "auto"
}
```

If no V10 exists yet:
```json
{
    "digest": null,
    "version": 0,
    "updatedAt": null,
    "lastUpdateSource": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `digest` | string or null | The health profile text |
| `version` | int | Incremented on every update |
| `updatedAt` | ISO datetime or null | Last update timestamp |
| `lastUpdateSource` | `"manual"` / `"auto"` / null | Whether last update was user edit or AI auto-update |

---

### `PUT /api/profile/v10`

Update the user's V10 health digest (manual edit).

**Request Body**:
```json
{
    "digest": "Conditions: Hypertension (diagnosed 2019)..."
}
```

| Field | Type | Required | Validation |
|-------|------|----------|-----------|
| `digest` | string | Yes | 1-5000 characters |

**Response** `200 OK`:
```json
{
    "digest": "Conditions: Hypertension (diagnosed 2019)...",
    "version": 4,
    "updatedAt": "2026-02-20T11:00:00Z",
    "lastUpdateSource": "manual"
}
```

---

## 5. Settings Endpoints

### `GET /api/settings`

Get the user's app settings.

**Response** `200 OK`:
```json
{
    "fontSize": "large",
    "highContrast": false,
    "disclaimerAcceptedAt": "2026-02-20T10:00:00Z",
    "disclaimerVersion": "1.0"
}
```

| Field | Type | Values | Default |
|-------|------|--------|---------|
| `fontSize` | string | `"regular"`, `"large"`, `"extraLarge"` | `"large"` |
| `highContrast` | boolean | true/false | false |
| `disclaimerAcceptedAt` | ISO datetime | — | Set on first accept |
| `disclaimerVersion` | string | — | Current version |

---

### `PUT /api/settings`

Update user settings. Partial update — only include fields to change.

**Request Body**:
```json
{
    "fontSize": "extraLarge",
    "highContrast": true
}
```

| Field | Type | Required | Validation |
|-------|------|----------|-----------|
| `fontSize` | string | No | One of: `regular`, `large`, `extraLarge` |
| `highContrast` | boolean | No | — |

**Response** `200 OK`: Returns the full updated settings object (same shape as GET).

---

### `POST /api/settings/accept-disclaimer`

Record disclaimer acceptance. Called once during onboarding.

**Request Body**:
```json
{
    "disclaimerVersion": "1.0"
}
```

**Response** `200 OK`:
```json
{
    "accepted": true,
    "disclaimerVersion": "1.0",
    "acceptedAt": "2026-02-20T10:00:00Z"
}
```

---

## 6. Account Endpoints

### `DELETE /api/account`

Permanently delete the user's account and all associated data.

**Request Body**:
```json
{
    "confirmation": "DELETE"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|-----------|
| `confirmation` | string | Yes | Must be exactly `"DELETE"` |

**Response** `200 OK`:
```json
{
    "deleted": true,
    "message": "Your account and all associated data have been permanently deleted."
}
```

**What this deletes**:
1. All messages for this user
2. All conversations for this user
3. V10 digest
4. User settings
5. User record
6. Firebase Auth account (via Admin SDK)

**Error Responses**:
| Status | Code | When |
|--------|------|------|
| 422 | `VALIDATION_ERROR` | Confirmation string doesn't match "DELETE" |

---

## 7. Pydantic Models (Backend)

```python
# src/models/chat.py
from pydantic import BaseModel, Field
from datetime import datetime


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=2000)
    conversation_id: str | None = Field(None, alias="conversationId")


class Citation(BaseModel):
    number: int
    title: str
    source: str
    url: str
    snippet: str = ""


class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    citations: list[Citation] = []
    confidence: str | None = None
    requires_emergency_care: bool = Field(False, alias="requiresEmergencyCare")
    created_at: datetime = Field(..., alias="createdAt")

    model_config = {"populate_by_name": True, "by_alias": True}


class ConversationSummary(BaseModel):
    id: str
    title: str
    last_message: str = Field("", alias="lastMessage")
    message_count: int = Field(0, alias="messageCount")
    created_at: datetime = Field(..., alias="createdAt")
    updated_at: datetime = Field(..., alias="updatedAt")

    model_config = {"populate_by_name": True, "by_alias": True}


class ConversationListResponse(BaseModel):
    conversations: list[ConversationSummary]
    has_more: bool = Field(..., alias="hasMore")
    next_cursor: str | None = Field(None, alias="nextCursor")

    model_config = {"populate_by_name": True, "by_alias": True}
```

```python
# src/models/profile.py
from pydantic import BaseModel, Field
from datetime import datetime


class V10DigestResponse(BaseModel):
    digest: str | None
    version: int = 0
    updated_at: datetime | None = Field(None, alias="updatedAt")
    last_update_source: str | None = Field(None, alias="lastUpdateSource")

    model_config = {"populate_by_name": True, "by_alias": True}


class V10DigestUpdate(BaseModel):
    digest: str = Field(..., min_length=1, max_length=5000)
```

```python
# src/models/settings.py
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class FontSize(str, Enum):
    regular = "regular"
    large = "large"
    extra_large = "extraLarge"


class SettingsResponse(BaseModel):
    font_size: FontSize = Field(FontSize.large, alias="fontSize")
    high_contrast: bool = Field(False, alias="highContrast")
    disclaimer_accepted_at: datetime | None = Field(None, alias="disclaimerAcceptedAt")
    disclaimer_version: str | None = Field(None, alias="disclaimerVersion")

    model_config = {"populate_by_name": True, "by_alias": True}


class SettingsUpdate(BaseModel):
    font_size: FontSize | None = Field(None, alias="fontSize")
    high_contrast: bool | None = Field(None, alias="highContrast")

    model_config = {"populate_by_name": True}
```

---

## 8. iOS Data Models

```swift
// Models/Message.swift
import Foundation

struct Message: Identifiable, Codable {
    let id: String
    let role: MessageRole
    let content: String
    let citations: [Citation]
    let confidence: String?
    let requiresEmergencyCare: Bool
    let createdAt: Date

    enum MessageRole: String, Codable {
        case user
        case assistant
    }
}

struct Citation: Identifiable, Codable {
    let number: Int
    let title: String
    let source: String
    let url: String
    let snippet: String

    var id: Int { number }
}
```

```swift
// Models/Conversation.swift
import Foundation

struct Conversation: Identifiable, Codable {
    let id: String
    let title: String
    let lastMessage: String
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
}

struct ConversationListResponse: Codable {
    let conversations: [Conversation]
    let hasMore: Bool
    let nextCursor: String?
}
```

```swift
// Models/V10Digest.swift
import Foundation

struct V10Digest: Codable {
    let digest: String?
    let version: Int
    let updatedAt: Date?
    let lastUpdateSource: String?
}
```

```swift
// Models/UserSettings.swift
import Foundation

struct UserSettings: Codable {
    var fontSize: FontSize
    var highContrast: Bool
    let disclaimerAcceptedAt: Date?
    let disclaimerVersion: String?

    enum FontSize: String, Codable {
        case regular
        case large
        case extraLarge
    }
}
```

```swift
// Models/APIError.swift
import Foundation

struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable {
    let code: String
    let message: String
    let details: [String: String]?
}

enum APIError: LocalizedError {
    case unauthorized
    case tokenExpired
    case validationError(String)
    case notFound
    case rateLimited
    case aiError
    case aiTimeout
    case serverError
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized, .tokenExpired:
            return "Your session has expired. Please log in again."
        case .validationError(let msg):
            return msg
        case .notFound:
            return "The requested content was not found."
        case .rateLimited:
            return "You're sending too many requests. Please wait a moment."
        case .aiError, .aiTimeout:
            return "We couldn't generate a response right now. Please try again."
        case .serverError:
            return "Something went wrong on our end. Please try again in a moment."
        case .networkError:
            return "You're not connected to the internet. Check your connection and try again."
        case .unknown(let msg):
            return msg
        }
    }
}
```
