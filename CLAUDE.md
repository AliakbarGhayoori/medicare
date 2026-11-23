# MediCare AI — Project Guide

Citation-backed medical assistant for elderly users. Native iOS (SwiftUI) + Python FastAPI backend. `google/gemini-4-neon` (via OpenRouter, with an automatic fallback model) with Tavily search for real-time medical evidence. Every health answer cites numbered search results, emergencies are detected and escalated.

## Stack

| Layer | Tech |
|-------|------|
| iOS | SwiftUI (iOS 17+), MVVM, Firebase Auth SDK 11.0+ |
| Backend | Python 3.12+, FastAPI, Motor (async MongoDB) |
| Database | MongoDB 7 (Docker local, Atlas prod) |
| AI | `google/gemini-4-neon` via OpenRouter chat completions (OpenAI SDK), fallback `openai/gpt-5.4` |
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

Production runs on this server; see **Production** below and `DEPLOY.md`.

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
│   │   │   ├── sources.py       # SourceRegistry: numbers search results per request
│   │   │   ├── citations.py     # finalize_citations(): renumber [n] against the registry
│   │   │   ├── policy.py        # needs_research(): small talk vs health question
│   │   │   ├── safety.py        # SAFETY_SIGNAL filter/parser, keyword fallback, crisis text
│   │   │   ├── client.py        # OpenAI-SDK client for OpenRouter + chat_model_options()
│   │   │   ├── tavily.py        # Tavily search wrapper (async)
│   │   │   └── v10_updater.py   # Post-chat async V10 update (NO_CHANGE protocol)
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
├── docker-compose.yml           # Local dev stack (project medicare-dev)
├── docker-compose.prod.yml      # Production stack (project medicare, env .env.prod)
├── deploy/nginx/                # Copies of the live nginx site configs
└── 0X_*.md                      # Design docs (architecture, API spec, UX, safety)
```

## Request Flow (Chat)

```
iOS → Bearer token → FastAPI auth middleware → Firebase verify_id_token()
→ Load V10 digest + conversation history
→ Build system prompt + user messages
→ Stream the model via OpenRouter with the tavily_search tool
  (health questions: tool_choice=required until AI_TOOL_MIN_CALLS searches)
→ Search results are numbered per request (SourceRegistry); the model cites [n]
→ SAFETY_SIGNAL line filtered out of the stream, then parsed (keyword check if missing)
→ Renumber citations, assess confidence, add crisis resources for self-harm
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
data: {"messageId": "...", "conversationId": "...", "content": "final text", "citations": [...], "confidence": "high", "requiresEmergencyCare": false}

event: error
data: {"code": "AI_ERROR", "message": "..."}
```

## Configuration

Backend env vars are loaded via Pydantic Settings (`src/config.py`). Select env file with `MEDICARE_ENV_FILE=.env.live`.

**WARNING**: `get_settings()` uses `lru_cache`. After changing `.env.live`, you MUST restart the backend process. The AI client is also a singleton — config changes require a full restart.

Key env vars:
- `AUTH_MODE`: `firebase` (real) or `mock` (dev, token format: `Bearer mock:<uid>`)
- `MOCK_AI`: `true` uses hardcoded responses, `false` uses real Claude
- `AI_MODEL`: `google/gemini-4-neon` (OpenRouter id with provider prefix; the legacy name `ANTHROPIC_MODEL` is still read)
- `AI_FALLBACK_MODELS`: tried in order when the primary fails, e.g. `["openai/gpt-5.4"]` (JSON list or comma-separated)
- `AI_MAX_TOKENS`: default 8192; reasoning tokens count against it (legacy name `ANTHROPIC_MAX_TOKENS`)
- `AI_REASONING_EFFORT`: optional `low` | `medium` | `high`
- `OPENROUTER_BASE_URL`: Must be `https://openrouter.ai/api` (the backend appends `/v1`; calls go to `/v1/chat/completions`)
- `AI_TOOL_MIN_CALLS`: Minimum Tavily searches before a health answer (default 2)
- `AI_TOOL_MAX_CALLS`: Maximum total tool calls (default 12)
- `TAVILY_INCLUDE_ANSWER`: keep `false` (only numbered search results may be cited)
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
- Health questions: `tool_choice="required"` until `AI_TOOL_MIN_CALLS` searches are done; small talk (`policy.needs_research`) is not forced
- The last round, or a spent `AI_TOOL_MAX_CALLS` budget, omits `tools` entirely (gemini-4-neon ignores `tool_choice="none"`)
- `reasoning_details` from each round must be sent back on the assistant message, or the model searches again
- Max `AI_TOOL_MAX_ROUNDS` rounds; each search emits `event: tool_use` (with its query) for the iOS status line

### Emergency Detection
- The model ends each answer with `SAFETY_SIGNAL: {"requiresEmergencyCare": ..., "category": ...}`; `SafetySignalFilter` keeps it out of the stream and `extract_ai_safety_signal` parses it
- No usable signal: regex patterns in `safety.py` decide (cardiac, stroke, breathing, severe_bleeding, consciousness, self_harm, poisoning, severe_pain)
- `done` event includes `requiresEmergencyCare: bool`
- The prompt names the local emergency number (112 EU/Denmark, 911 US/Canada, 999 UK, 000 Australia); self-harm answers get international crisis resources (988 in the US, findahelpline.com)

### V10 Health Profile
- Injected into AI system prompt for personalization
- Auto-updated after chat via async task (non-blocking)
- Versioned with revert capability
- Max 5000 chars
- The updater replies `NO_CHANGE` when nothing new was stated; empty, placeholder, truncated or unchanged replies are never saved
- `usable_digest()` hides the legacy placeholder `(No health profile set up yet)` from the API and the prompt

### iOS SSE Streaming
- `SSEClient` uses dedicated URLSession with 300s request timeout / 600s resource timeout
- Default `URLSession.shared` is too short (~60s) for AI responses that include Tavily searches (~30-60s)
- Chat view shows "Searching..." during tool_use events

## Gotchas

1. **XcodeGen**: After changing `project.yml`, run `xcodegen generate`. The `.xcodeproj` won't auto-update.
2. **GoogleService-Info.plist**: Must be in `ios/MediCareAI/Resources/` AND referenced in the xcodeproj. Regenerate with xcodegen if missing.
3. **OpenRouter model names**: Must include provider prefix (`google/gemini-4-neon`, not just `gemini-4-neon`)
4. **OpenRouter base URL**: Must be `https://openrouter.ai/api`; the backend appends `/v1`
5. **Settings cache**: `lru_cache` + singleton client = restart backend after any `.env` change
6. **Firebase client_email format**: `firebase-adminsdk-XXXXX@PROJECT_ID.iam.gserviceaccount.com` (must have `@`)
7. **Firebase Admin SDK**: Requires `token_uri: "https://oauth2.googleapis.com/token"` in credential dict
8. **iOS date decoding**: Custom decoder in `Coding.swift` must handle `null` for optional Date fields (new users have null `updatedAt`)
9. **Python version**: Project uses 3.14 locally but targets 3.12+. Venv is at `backend/.venv/`
10. **gemini-4-neon quirks**: ignores `tool_choice="none"` (omit `tools` to force an answer), needs `reasoning_details` passed back, and spends ~600 reasoning tokens of `max_tokens`
11. **Production compose**: always `docker compose --env-file .env.prod -f docker-compose.prod.yml ...`; plain `docker compose` uses the dev file (project `medicare-dev`)
12. **Privacy**: logs must never contain question, search query, answer or profile text

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

- `users` — user metadata and settings (fontSize, highContrast, disclaimer)
- `conversations` — conversation headers (firebaseUid, title, createdAt)
- `messages` — chat messages (conversationId, role, content, citations)
- `v10Memories` — health profile (firebaseUid, digest, previousDigest, version)
- `analyticsEvents` — event tracking

All documents keyed by `firebaseUid` for ownership. Indexes auto-created at startup.

## Firebase

- Project: `medicare-8fd9e`
- API Key (client): `AIzaSyCgscu7VyT35jxvR5Dbs0zXk4WSW7tTL6o`
- Auth method: Email/Password (must be enabled in Firebase Console)
- iOS bundle ID: `com.medicareai.app`
- Admin SDK JSON: downloaded from Firebase Console → Project Settings → Service Accounts

## Production

- Runs on this server. Host nginx (`deploy/nginx/`) terminates TLS for `api.mediguide.co` and proxies `/health` and `/api/` to `127.0.0.1:8000`; `mediguide.co` is served from `/root/medicare/website`.
- Containers `medicare-backend` and `medicare-mongo` (compose project `medicare`, `docker-compose.prod.yml`, settings in the git-ignored `.env.prod`).
- Deploy: `docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build`. Tag the running image before every deploy so it can be rolled back; see `DEPLOY.md`.
- The repository is public: never commit `.env*` files, passwords or keys.
