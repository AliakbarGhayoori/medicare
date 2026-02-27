# System Architecture — MediCare AI

**Date**: February 2026
**Stack**: SwiftUI iOS + FastAPI + MongoDB + Claude Opus 4.6

---

## 1. Architecture Overview

```
┌──────────────┐     HTTPS/SSE      ┌──────────────────┐
│              │ ◄────────────────► │                  │
│   iOS App    │   Firebase Token    │   FastAPI         │
│  (SwiftUI)   │                     │   Backend         │
│              │                     │                  │
└──────────────┘                     ├──────────────────┤
                                     │  ┌─────────┐     │
                                     │  │ Anthropic│     │
                                     │  │ API      │     │
                                     │  │(Opus 4.6)│     │
                                     │  └─────────┘     │
                                     │  ┌─────────┐     │
                                     │  │ MongoDB  │     │
                                     │  │ (Motor)  │     │
                                     │  └─────────┘     │
                                     │  ┌─────────┐     │
                                     │  │ Firebase │     │
                                     │  │ Admin    │     │
                                     │  └─────────┘     │
                                     └──────────────────┘
```

**Style**: Client-server with a single AI runtime path. No microservices, no message queues, no multi-agent orchestration.

**Key Principle**: Every user request follows one path: iOS → FastAPI → Claude (with tools) → FastAPI → iOS. No fan-out, no async workers in the request path.

---

## 2. Runtime Flow (Request Lifecycle)

### Chat Request: User Asks a Health Question

```
Step 1: User types question, taps Send
Step 2: iOS attaches Firebase ID token, opens SSE connection to POST /api/chat/ask
Step 3: FastAPI middleware verifies Firebase token → extracts uid
Step 4: Backend loads:
        - V10 digest for this user
        - Last N messages from current conversation (for context)
Step 5: Backend constructs the prompt:
        - System prompt (medical assistant role, safety rules, citation requirements)
        - V10 digest (injected as context)
        - Conversation history (last N messages)
        - User's new question
Step 6: Backend calls Anthropic API with:
        - model: claude-opus-4-6
        - messages: [system, ...history, user_question]
        - tools: [web_search, web_fetch] (Anthropic built-in)
        - stream: true
Step 7: Model processes (may invoke web_search/web_fetch tools autonomously)
Step 8: Backend streams tokens to iOS via SSE as they arrive
Step 9: Backend detects emergency flags in the response
Step 10: When stream completes:
         - Backend persists the full message (content, citations, confidence, emergency flag)
         - Backend triggers V10 digest update (async, after response sent)
         - Backend sends final SSE event with metadata (citations array, confidence, emergency flag)
Step 11: iOS renders the complete message with citation badges and emergency banner if needed
```

### V10 Digest Update (Post-Response, Async)

```
Step 1: After chat response is fully sent to user
Step 2: Backend calls Claude with a focused prompt:
        "Given this conversation and the existing V10 digest, produce an updated digest."
Step 3: If digest changed:
        - Save new digest version
        - Include diff in next iOS response or push a lightweight notification
Step 4: This runs AFTER the user gets their response (no latency impact)
```

---

## 3. Streaming Architecture (SSE)

### Why SSE (Not WebSocket)
- SSE is simpler: unidirectional (server → client), works over standard HTTP, auto-reconnects.
- We only need server → client streaming (token delivery). Client → server is standard HTTP POST.
- WebSocket is overkill for this use case and adds connection management complexity.

### SSE Protocol

Backend sends events in this format:

```
event: token
data: {"text": "Based on"}

event: token
data: {"text": " your symptoms"}

event: token
data: {"text": ", this could"}

... (tokens stream in real-time)

event: done
data: {"messageId": "msg_abc", "citations": [...], "confidence": "medium", "requiresEmergencyCare": false}
```

**Event types**:
| Event | Purpose | Data Shape |
|-------|---------|-----------|
| `token` | Incremental text chunk | `{"text": "..."}` |
| `tool_use` | Notify client that model is searching | `{"tool": "web_search", "status": "searching"}` |
| `done` | Stream complete, final metadata | `{"messageId", "citations", "confidence", "requiresEmergencyCare"}` |
| `error` | Stream-level error | `{"code": "...", "message": "..."}` |

### FastAPI Streaming Implementation

```python
from fastapi import Request
from fastapi.responses import StreamingResponse
from anthropic import Anthropic
import json


async def stream_chat_response(
    question: str,
    system_prompt: str,
    messages: list[dict],
    v10_digest: str | None,
) -> StreamingResponse:
    client = Anthropic()  # uses ANTHROPIC_API_KEY env var

    # Build the full message list
    full_messages = build_messages(messages, question, v10_digest)

    async def event_generator():
        accumulated_text = ""

        with client.messages.stream(
            model="claude-opus-4-6",
            max_tokens=4096,
            system=system_prompt,
            messages=full_messages,
            tools=get_medical_tools(),  # web_search, web_fetch
        ) as stream:
            for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, "text"):
                        chunk = event.delta.text
                        accumulated_text += chunk
                        yield f"event: token\ndata: {json.dumps({'text': chunk})}\n\n"

                elif event.type == "tool_use":
                    yield f"event: tool_use\ndata: {json.dumps({'tool': event.name, 'status': 'searching'})}\n\n"

        # After stream completes, extract metadata
        citations = extract_citations(stream.get_final_message())
        confidence = assess_confidence(accumulated_text, citations)
        emergency = detect_emergency(accumulated_text)

        yield f"event: done\ndata: {json.dumps({'citations': citations, 'confidence': confidence, 'requiresEmergencyCare': emergency})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Disable nginx buffering
        },
    )
```

### iOS SSE Client

```swift
import Foundation

final class SSEClient {
    func streamChat(question: String, conversationId: String?) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let request = buildRequest(question: question, conversationId: conversationId)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        return AsyncThrowingStream { continuation in
            Task {
                var currentEvent = ""
                var currentData = ""

                for try await line in bytes.lines {
                    if line.hasPrefix("event: ") {
                        currentEvent = String(line.dropFirst(7))
                    } else if line.hasPrefix("data: ") {
                        currentData = String(line.dropFirst(6))

                        if let data = currentData.data(using: .utf8) {
                            switch currentEvent {
                            case "token":
                                if let payload = try? JSONDecoder().decode(TokenEvent.self, from: data) {
                                    continuation.yield(.token(payload.text))
                                }
                            case "tool_use":
                                continuation.yield(.searching)
                            case "done":
                                if let payload = try? JSONDecoder().decode(DoneEvent.self, from: data) {
                                    continuation.yield(.done(payload))
                                }
                                continuation.finish()
                            case "error":
                                continuation.finish(throwing: APIError.streamError)
                            default:
                                break
                            }
                        }
                        currentEvent = ""
                        currentData = ""
                    }
                }
                continuation.finish()
            }
        }
    }
}
```

---

## 4. iOS Architecture

### Layer Diagram

```
┌─────────────────────────────────────────┐
│                Views                     │  SwiftUI screens
│  AuthView, ChatView, V10View, Settings  │
├─────────────────────────────────────────┤
│              ViewModels                  │  @MainActor ObservableObject
│  AuthVM, ChatVM, V10VM, SettingsVM      │
├─────────────────────────────────────────┤
│               Services                   │  Network + Firebase
│  APIService, AuthService, SSEClient     │
├─────────────────────────────────────────┤
│                Models                    │  Codable structs
│  Message, Citation, V10Digest, User     │
└─────────────────────────────────────────┘
```

### Key Patterns

**MVVM with @MainActor**:
```swift
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var streamingText: String = ""
    @Published var isStreaming = false
    @Published var isSearching = false  // shows "Searching medical sources..."
    @Published var errorMessage: String?

    private let api: APIService

    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message immediately (optimistic)
        let userMessage = Message(role: .user, content: content, createdAt: .now)
        messages.append(userMessage)

        isStreaming = true
        streamingText = ""
        errorMessage = nil

        do {
            let stream = try await api.streamChat(question: content, conversationId: currentConversationId)

            for try await event in stream {
                switch event {
                case .token(let text):
                    isSearching = false
                    streamingText += text
                case .searching:
                    isSearching = true
                case .done(let metadata):
                    let assistantMessage = Message(
                        role: .assistant,
                        content: streamingText,
                        citations: metadata.citations,
                        confidence: metadata.confidence,
                        requiresEmergencyCare: metadata.requiresEmergencyCare,
                        createdAt: .now
                    )
                    messages.append(assistantMessage)
                    streamingText = ""
                    isStreaming = false
                }
            }
        } catch {
            isStreaming = false
            streamingText = ""
            errorMessage = "We couldn't complete that request. Please try again."
        }
    }
}
```

**Auth State Management**:
```swift
@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthState {
        case loading      // Checking token on launch
        case authenticated // Valid session
        case unauthenticated // No session or expired
    }

    @Published var state: AuthState = .loading
    @Published var errorMessage: String?

    private let authService: AuthService

    func checkAuthState() async {
        state = .loading
        if let user = authService.currentUser {
            // Verify token is still valid
            do {
                try await user.getIDToken()
                state = .authenticated
            } catch {
                state = .unauthenticated
            }
        } else {
            state = .unauthenticated
        }
    }
}
```

### File Structure

```
ios/MediCareAI/
├── App/
│   ├── MediCareAIApp.swift         # @main, app entry, environment setup
│   └── ContentView.swift            # Root: auth gate → tabs or login
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── ForgotPasswordView.swift
│   ├── Chat/
│   │   ├── ChatView.swift           # Chat thread with messages
│   │   ├── MessageBubbleView.swift  # Single message rendering
│   │   ├── CitationBadgeView.swift  # Tappable [1] [2] badges
│   │   ├── CitationDetailSheet.swift
│   │   ├── EmergencyBannerView.swift
│   │   ├── ChatInputBar.swift
│   │   ├── StreamingTextView.swift  # Renders text as it streams in
│   │   └── EmptyChatView.swift      # Welcome + suggestions
│   ├── Conversations/
│   │   └── ConversationListView.swift
│   ├── V10/
│   │   ├── V10MemoryView.swift      # Display mode
│   │   └── V10EditorView.swift      # Edit mode
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── AboutView.swift
│   └── Onboarding/
│       ├── OnboardingView.swift     # Pager with 3 screens
│       └── DisclaimerView.swift     # Must-accept disclaimer
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ChatViewModel.swift
│   ├── ConversationListViewModel.swift
│   ├── V10ViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── APIService.swift             # HTTP client + SSE
│   ├── AuthService.swift            # Firebase Auth wrapper
│   └── SSEClient.swift              # SSE stream parser
├── Models/
│   ├── Message.swift
│   ├── Citation.swift
│   ├── Conversation.swift
│   ├── V10Digest.swift
│   ├── UserSettings.swift
│   └── APIError.swift
├── Utilities/
│   ├── KeychainHelper.swift         # Token storage
│   └── DateFormatting.swift
└── Resources/
    ├── Assets.xcassets/             # Colors (light/dark/high-contrast)
    ├── GoogleService-Info.plist     # Firebase config
    └── Localizable.strings
```

---

## 5. Backend Architecture

### Package Layout

```
backend/
├── src/
│   ├── __init__.py
│   ├── main.py                      # FastAPI app creation, middleware, routers
│   ├── config.py                    # Pydantic Settings (env vars)
│   ├── api/
│   │   ├── __init__.py
│   │   ├── chat.py                  # POST /ask (SSE), GET /history
│   │   ├── profile.py               # GET/PUT /v10
│   │   └── settings.py              # GET/PUT /settings
│   ├── services/
│   │   ├── __init__.py
│   │   ├── chat_service.py          # Chat business logic
│   │   ├── profile_service.py       # V10 digest CRUD + update
│   │   └── settings_service.py      # User settings CRUD
│   ├── ai/
│   │   ├── __init__.py
│   │   ├── client.py                # Anthropic client singleton
│   │   ├── prompts.py               # System prompts, prompt builder
│   │   ├── stream.py                # SSE streaming handler
│   │   ├── citations.py             # Citation extraction from tool results
│   │   ├── safety.py                # Emergency detection, confidence assessment
│   │   └── v10_updater.py           # Post-conversation V10 digest update
│   ├── db/
│   │   ├── __init__.py
│   │   ├── mongo.py                 # Motor client + get_db
│   │   └── indexes.py               # Index creation on startup
│   ├── dependencies/
│   │   ├── __init__.py
│   │   ├── auth.py                  # Firebase token verification dependency
│   │   └── database.py              # DB session dependency
│   └── models/
│       ├── __init__.py
│       ├── chat.py                  # ChatRequest, ChatResponse, Message pydantic models
│       ├── profile.py               # V10Digest model
│       ├── settings.py              # UserSettings model
│       └── common.py                # Shared models (Citation, etc.)
├── tests/
│   ├── conftest.py                  # Fixtures: test client, mock DB, mock auth
│   ├── test_chat.py
│   ├── test_profile.py
│   ├── test_settings.py
│   ├── test_safety.py               # Emergency detection test scenarios
│   ├── test_citations.py
│   └── test_v10_updater.py
├── Dockerfile
├── requirements.txt
├── pyproject.toml                   # ruff, mypy config
└── .env.example
```

### App Entry Point

```python
# src/main.py
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.config import settings
from src.api import chat, profile, settings as settings_router
from src.db.indexes import ensure_indexes
from src.db.mongo import get_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure indexes
    db = get_db()
    await ensure_indexes(db)
    yield
    # Shutdown: cleanup if needed


app = FastAPI(
    title="MediCare AI API",
    version="3.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(chat.router, prefix="/api/chat", tags=["chat"])
app.include_router(profile.router, prefix="/api/profile", tags=["profile"])
app.include_router(settings_router.router, prefix="/api/settings", tags=["settings"])


@app.get("/health")
async def health():
    return {"status": "healthy", "version": "3.0"}
```

### Configuration

```python
# src/config.py
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Firebase
    firebase_project_id: str
    firebase_client_email: str
    firebase_private_key: str

    # MongoDB
    mongodb_uri: str
    mongodb_database: str = "medicare-ai"

    # Anthropic
    anthropic_api_key: str
    anthropic_model: str = "claude-opus-4-6"
    anthropic_max_tokens: int = 4096

    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    allowed_origins: list[str] = ["http://localhost:3000"]
    environment: str = "development"

    # Chat
    max_conversation_context_messages: int = 20  # Last N messages sent to model
    max_question_length: int = 2000

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
```

### Auth Dependency

```python
# src/dependencies/auth.py
from fastapi import Depends, Header, HTTPException
from firebase_admin import auth, credentials, initialize_app
from src.config import settings

# Initialize Firebase Admin once
_firebase_initialized = False

def _ensure_firebase():
    global _firebase_initialized
    if not _firebase_initialized:
        cred = credentials.Certificate({
            "type": "service_account",
            "project_id": settings.firebase_project_id,
            "client_email": settings.firebase_client_email,
            "private_key": settings.firebase_private_key.replace("\\n", "\n"),
        })
        initialize_app(cred)
        _firebase_initialized = True


async def get_current_user_uid(authorization: str = Header(default="")) -> str:
    """FastAPI dependency: extract and verify Firebase UID from Bearer token."""
    _ensure_firebase()

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    token = authorization.split(" ", 1)[1]
    try:
        decoded = auth.verify_id_token(token)
    except auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired")
    except auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")

    return decoded["uid"]
```

### Error Handling

```python
# All API errors return a consistent envelope:
{
    "error": {
        "code": "VALIDATION_ERROR",
        "message": "Question cannot be empty.",
        "details": {}  # optional
    }
}
```

```python
# src/models/common.py
from pydantic import BaseModel


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: dict | None = None


class ErrorResponse(BaseModel):
    error: ErrorDetail
```

Error codes:
| Code | HTTP Status | Meaning |
|------|------------|---------|
| `UNAUTHORIZED` | 401 | Missing or invalid auth token |
| `TOKEN_EXPIRED` | 401 | Firebase token needs refresh |
| `VALIDATION_ERROR` | 422 | Bad request data |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `RATE_LIMITED` | 429 | Too many requests |
| `AI_ERROR` | 502 | Anthropic API error |
| `AI_TIMEOUT` | 504 | Anthropic API timeout |
| `INTERNAL_ERROR` | 500 | Unexpected server error |

---

## 6. Caching Strategy (Phase 1 — Minimal)

Phase 1 does **not** include a Redis/Memcached layer. Caching is limited to:

1. **Firebase Admin token cache**: Built into the Firebase Admin SDK (caches public keys for token verification).
2. **V10 digest in-memory**: If the same user sends multiple messages in a session, the V10 digest is loaded once and reused.
3. **No response caching**: Every medical question gets a fresh AI response with current web evidence. Caching medical answers is risky (evidence changes, user context differs).

Phase 2 consideration: Cache common non-personalized medical lookups (e.g., "what is ibuprofen") with a short TTL.

---

## 7. Rate Limiting

### Phase 1 Implementation
Simple per-user rate limiting via an in-memory counter (or MongoDB counter for multi-process):

| Limit | Value | Scope |
|-------|-------|-------|
| Chat requests | 30 per hour per user | Per Firebase UID |
| V10 updates | 10 per hour per user | Per Firebase UID |
| Auth attempts | 5 per 15 minutes per IP | Per IP address |

```python
# Simple in-memory rate limiter for Phase 1
# Replace with Redis-backed limiter in Phase 2 for multi-process
from collections import defaultdict
from time import time

_rate_limits: dict[str, list[float]] = defaultdict(list)

def check_rate_limit(key: str, max_requests: int, window_seconds: int) -> bool:
    now = time()
    _rate_limits[key] = [t for t in _rate_limits[key] if now - t < window_seconds]
    if len(_rate_limits[key]) >= max_requests:
        return False
    _rate_limits[key].append(now)
    return True
```

---

## 8. Security Architecture

### Authentication Flow
```
iOS App                    FastAPI                     Firebase
  │                          │                            │
  │── Sign in ──────────────►│                            │
  │                          │                            │
  │◄── Firebase ID Token ───│◄── Token issued ──────────│
  │                          │                            │
  │── API Request ──────────►│                            │
  │   (Bearer token)         │── Verify token ──────────►│
  │                          │◄── UID + claims ─────────│
  │                          │                            │
  │◄── Response ────────────│                            │
```

### Security Checklist
- [ ] All API endpoints (except `/health`) require valid Firebase token
- [ ] CORS restricted to known origins (not `*` in production)
- [ ] HTTPS/TLS everywhere (enforce in production)
- [ ] Firebase private key in env var, never in code
- [ ] Anthropic API key in env var, never in code
- [ ] MongoDB connection string in env var, never in code
- [ ] No PHI in application logs (redact user content before logging)
- [ ] Rate limiting on all user-facing endpoints
- [ ] Input validation on all endpoints (max length, type checks)
- [ ] No raw exception details in API responses (generic error messages)

---

## 9. Performance Targets

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Time to first SSE token | < 3s (p95) | Server-side timer: request received → first `token` event sent |
| Full response completion | < 15s (p95) | Server-side timer: request received → `done` event sent |
| Auth verification | < 100ms (p95) | Firebase Admin SDK with cached public keys |
| V10 digest load | < 50ms (p95) | MongoDB indexed query |
| Conversation history load | < 200ms (p95) | MongoDB indexed query with limit |
| iOS app launch → interactive | < 1.5s | Xcode Instruments: Time to Interactive |
| Chat scroll frame rate | 60fps | Xcode Instruments: Core Animation |

---

## 10. Dependency Versions (Phase 1)

### Backend (Python)
```
python = "3.12+"
fastapi = ">=0.115"
uvicorn = {extras = ["standard"], version = ">=0.34"}
motor = ">=3.6"
firebase-admin = ">=6.6"
pydantic = ">=2.10"
pydantic-settings = ">=2.7"
anthropic = ">=0.42"
httpx = ">=0.28"
python-dotenv = ">=1.0"
```

### Backend (Dev/Test)
```
pytest = ">=8.0"
pytest-asyncio = ">=0.25"
ruff = ">=0.9"
mypy = ">=1.14"
```

### iOS
```
Swift 5.9+
iOS 17.0+ deployment target
firebase-ios-sdk ~> 11.0
```

No third-party iOS dependencies beyond Firebase. Use native URLSession, SwiftUI, and Foundation.
