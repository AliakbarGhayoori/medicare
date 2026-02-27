# MediCare AI — Project Guide

Citation-backed medical assistant for elderly users. Native iOS (SwiftUI) + Python FastAPI backend. Claude Opus 4.6 with Tavily search for real-time medical evidence. Every response is citation-backed, emergencies are detected and escalated.

## Stack

| Layer | Tech |
|-------|------|
| iOS | SwiftUI (iOS 17+), MVVM, Firebase Auth SDK 11.0+ |
| Backend | Python 3.12+, FastAPI, Motor (async MongoDB) |
| Database | MongoDB 7 (Docker local, Atlas prod) |
| AI | Claude Opus 4.6 via Anthropic SDK (OpenRouter passthrough) |
| Search | Tavily API (advanced depth, up to 6 results per query) |
| Streaming | Server-Sent Events (SSE) |
| Auth | Firebase Authentication (email/password) |

## Quick Start

```bash
# Backend
cd backend
docker compose up -d                    # MongoDB
MEDICARE_ENV_FILE=.env.live .venv/bin/python -m uvicorn src.main:app --host 127.0.0.1 --port 8000

# iOS
cd ios
xcodegen generate                       # Regenerate xcodeproj from project.yml
# Xcode: scheme "MediCareAI-Live" → iPhone 17 Pro → Cmd+R

# Tests
cd backend
.venv/bin/python -m pytest tests/ -v                          # Unit tests
MEDICARE_ENV_FILE=.env.live .venv/bin/python scripts/live_e2e_check.py  # E2E
```

## Directory Structure

```
medicare/
├── backend/
│   ├── src/
│   │   ├── main.py              # FastAPI app, CORS, routers, lifespan
│   │   ├── config.py            # Pydantic Settings (env vars, lru_cache)
│   │   ├── exceptions.py        # APIError class
│   │   ├── api/
│   │   │   ├── chat.py          # POST /ask (SSE), GET /history, GET /history/{id}
│   │   │   ├── profile.py       # GET/PUT /v10, POST /v10/revert
│   │   │   ├── settings.py      # GET/PUT /settings, POST /accept-disclaimer
│   │   │   └── account.py       # DELETE /account
│   │   ├── ai/
│   │   │   ├── stream.py        # generate_response_events() — SSE + tool loop
│   │   │   ├── prompts.py       # System prompt with V10 context injection
│   │   │   ├── citations.py     # Regex citation extraction + validation
│   │   │   ├── safety.py        # Emergency detection + confidence scoring
│   │   │   ├── client.py        # Anthropic client singleton
│   │   │   ├── tavily.py        # Tavily search wrapper (async)
│   │   │   └── v10_updater.py   # Post-chat async V10 digest update
│   │   ├── services/
│   │   │   ├── chat_service.py      # Message/conversation CRUD
│   │   │   ├── profile_service.py   # V10 digest CRUD with versioning
│   │   │   ├── settings_service.py  # User settings + disclaimer
│   │   │   ├── rate_limiter.py      # In-memory sliding window
│   │   │   ├── analytics.py         # Event tracking to MongoDB
│   │   │   └── account_service.py   # Account deletion
│   │   ├── dependencies/
│   │   │   ├── auth.py          # Firebase token verify + mock mode
│   │   │   └── database.py      # Motor async DB session
│   │   └── models/              # Pydantic request/response models
│   │       ├── chat.py, profile.py, settings.py, common.py, account.py
│   ├── tests/                   # pytest-asyncio, 14 test files
│   ├── scripts/
│   │   └── live_e2e_check.py    # Full live E2E test (Firebase + AI + Tavily)
│   ├── .env.live                # Live config (Firebase + OpenRouter + Tavily)
│   └── pyproject.toml           # Ruff, mypy, pytest config
│
├── ios/
│   ├── project.yml              # XcodeGen spec (regenerate with `xcodegen generate`)
│   ├── MediCareAI/
│   │   ├── App/                 # MediCareAIApp.swift, AppContext.swift, RootView.swift
│   │   ├── Views/               # Auth/, Chat/, Conversations/, V10/, Settings/, Onboarding/
│   │   ├── ViewModels/          # AuthViewModel, ChatViewModel, V10ViewModel, etc.
│   │   ├── Services/            # APIService.swift, AuthService.swift, SSEClient.swift
│   │   ├── Models/              # Codable DTOs (Message, Citation, V10Digest, etc.)
│   │   ├── Utilities/           # Coding.swift (JSON decoders), ErrorHandling.swift
│   │   └── Resources/           # GoogleService-Info.plist, Assets
│
├── docker-compose.yml           # MongoDB + backend containers
└── 0X_*.md                      # Design docs (architecture, API spec, UX, safety)
```

## Request Flow (Chat)

```
iOS → Bearer token → FastAPI auth middleware → Firebase verify_id_token()
→ Load V10 digest + conversation history
→ Build system prompt + user messages
→ Stream Claude Opus 4.6 with tavily_search tool (3-12 calls enforced)
→ Extract citations, assess confidence, detect emergency
→ Save message to MongoDB, trigger async V10 update
→ Stream SSE: tool_use → token → done
```

## SSE Protocol

```
event: tool_use
data: {"tool": "tavily_search", "status": "searching", "query": "metformin side effects"}

event: token
data: {"text": "Based on current research, "}

event: done
data: {"messageId": "...", "conversationId": "...", "citations": [...], "confidence": "high", "requiresEmergencyCare": false}

event: error
data: {"code": "AI_ERROR", "message": "..."}
```

## Configuration

Backend env vars are loaded via Pydantic Settings (`src/config.py`). Select env file with `MEDICARE_ENV_FILE=.env.live`.

**WARNING**: `get_settings()` uses `lru_cache`. After changing `.env.live`, you MUST restart the backend process. The AI client is also a singleton — config changes require a full restart.

Key env vars:
- `AUTH_MODE`: `firebase` (real) or `mock` (dev, token format: `Bearer mock:<uid>`)
- `MOCK_AI`: `true` uses hardcoded responses, `false` uses real Claude
- `AI_PROVIDER`: `anthropic` (direct) or `openrouter` (passthrough)
- `ANTHROPIC_MODEL`: `anthropic/claude-opus-4.6` (needs `anthropic/` prefix for OpenRouter)
- `OPENROUTER_BASE_URL`: Must be `https://openrouter.ai/api` (SDK appends `/v1/messages`)
- `AI_TOOL_MIN_CALLS`: Minimum Tavily searches per response (default 3)
- `AI_TOOL_MAX_CALLS`: Maximum total tool calls (default 12)
- `CHAT_RATE_LIMIT_PER_HOUR`: 30 per user
- `V10_RATE_LIMIT_PER_HOUR`: 10 per user

## iOS Schemes

- **MediCareAI**: `AUTH_MODE=mock` — mock auth + localhost backend. For offline dev.
- **MediCareAI-Live**: `AUTH_MODE=firebase` — real Firebase auth + localhost backend. For live testing.

Always use **MediCareAI-Live** when testing against the real backend. Using the wrong scheme sends `mock:uid_xxx` tokens which the Firebase backend rejects with 401.

## Key Patterns

### Pydantic Models
- Snake_case fields with camelCase aliases: `Field(alias="camelCase")`
- Always: `model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)`

### Error Responses
- All errors: `{"error": {"code": "...", "message": "...", "details": {...}}}`
- Codes: `UNAUTHORIZED`, `TOKEN_EXPIRED`, `VALIDATION_ERROR`, `NOT_FOUND`, `RATE_LIMITED`, `AI_ERROR`, `AI_TIMEOUT`, `INTERNAL_ERROR`
- Rate limit 429 includes `Retry-After` header

### Auth
- iOS sends: `Authorization: Bearer <firebase-id-token>`
- Backend dependency: `user: AuthUser = Depends(get_current_user)`
- Firebase Admin SDK needs `token_uri` in credential dict
- Private key: `.replace("\\n", "\n")` on load

### Tool Calling (AI)
- Model MUST call `tavily_search` at least `AI_TOOL_MIN_CALLS` times
- If it stops early, backend re-prompts: "Call tavily_search at least N more times"
- Max `AI_TOOL_MAX_ROUNDS` rounds of tool calling
- Each tool call emits `event: tool_use` to iOS for UI feedback

### Emergency Detection
- Regex patterns in `safety.py` for: cardiac, stroke, breathing, severe_bleeding, consciousness, self_harm, poisoning, severe_pain
- `done` event includes `requiresEmergencyCare: bool`
- Emergency responses include crisis hotline numbers

### V10 Health Profile
- Injected into AI system prompt for personalization
- Auto-updated after chat via async task (non-blocking)
- Versioned with revert capability
- Max 5000 chars

### iOS SSE Streaming
- `SSEClient` uses dedicated URLSession with 300s request timeout / 600s resource timeout
- Default `URLSession.shared` is too short (~60s) for AI responses that include Tavily searches (~30-60s)
- Chat view shows "Searching..." during tool_use events

## Gotchas

1. **XcodeGen**: After changing `project.yml`, run `xcodegen generate`. The `.xcodeproj` won't auto-update.
2. **GoogleService-Info.plist**: Must be in `ios/MediCareAI/Resources/` AND referenced in the xcodeproj. Regenerate with xcodegen if missing.
3. **OpenRouter model names**: Must include provider prefix (`anthropic/claude-opus-4.6`, not just `claude-opus-4.6`)
4. **OpenRouter base URL**: Must be `https://openrouter.ai/api` — the Anthropic SDK appends `/v1/messages`
5. **Settings cache**: `lru_cache` + singleton client = restart backend after any `.env` change
6. **Firebase client_email format**: `firebase-adminsdk-XXXXX@PROJECT_ID.iam.gserviceaccount.com` (must have `@`)
7. **Firebase Admin SDK**: Requires `token_uri: "https://oauth2.googleapis.com/token"` in credential dict
8. **iOS date decoding**: Custom decoder in `Coding.swift` must handle `null` for optional Date fields (new users have null `updatedAt`)
9. **Python version**: Project uses 3.14 locally but targets 3.12+. Venv is at `backend/.venv/`
10. **Gemini via OpenRouter**: Only Anthropic models work on the `/v1/messages` endpoint. Gemini/OpenAI models need different API formats.

## Linting & Code Style

```bash
# Backend
ruff check src/ --fix          # Lint
ruff format src/               # Format
mypy src/                      # Type check

# Config: pyproject.toml
# 100-char lines, double quotes, LF endings
# Rules: E, F, W, I, B, UP, N (ignore B008 for FastAPI Depends)
```

## MongoDB Collections

- `users` — user metadata
- `conversations` — conversation headers (firebaseUid, title, createdAt)
- `messages` — chat messages (conversationId, role, content, citations)
- `v10_digests` — health profile versions (firebaseUid, digest, version)
- `user_settings` — preferences (fontSize, highContrast, disclaimer)
- `analytics_events` — event tracking

All documents keyed by `firebaseUid` for ownership. Indexes auto-created at startup.

## Firebase

- Project: `medicare-8fd9e`
- API Key (client): `AIzaSyCgscu7VyT35jxvR5Dbs0zXk4WSW7tTL6o`
- Auth method: Email/Password (must be enabled in Firebase Console)
- iOS bundle ID: `com.medicareai.app`
- Admin SDK JSON: downloaded from Firebase Console → Project Settings → Service Accounts
