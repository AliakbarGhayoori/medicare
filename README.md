# MediCare AI

**A trusted, citation-backed medical assistant for elderly users.**

Native iOS app + Python FastAPI backend, powered by Gemini 3.1 Pro via OpenRouter with real-time Tavily web evidence retrieval.

---

## What This Is

MediCare AI helps elderly users get reliable medical guidance through a simple chat interface. Every medical claim is backed by citations from trusted sources. The app detects emergency symptoms and escalates immediately. It remembers the user's health context (V10 digest) to personalize every response.

This is **not** a licensed clinician, medical device, or FDA-regulated product. It is a consumer health assistant that provides supportive guidance and strongly encourages professional follow-up.

---

## Technical Stack

| Layer | Technology |
|-------|-----------|
| iOS Client | SwiftUI (iOS 17+), MVVM, Firebase Auth SDK |
| Backend API | Python 3.12+, FastAPI, Motor (async MongoDB), Firebase Admin SDK |
| Database | MongoDB 7 (Docker local, Atlas or Docker for prod) |
| AI Model | Gemini 3.1 Pro via OpenRouter (OpenAI Chat Completions format) |
| AI Tools | Tavily search via model function-calling for real-time medical evidence |
| Streaming | Server-Sent Events (SSE) for real-time response delivery |
| Auth | Firebase Authentication (email/password) |
| Deployment | Docker Compose + Caddy (auto-HTTPS) on single VPS |

---

## Quick Start (Development)

```bash
# 1. Clone and enter
git clone <repo-url> && cd medicare

# 2. Backend
cp .env.example .env  # fill in Firebase + OpenRouter + Tavily keys
docker compose up -d mongo
cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# 3. iOS
open ios/MediCareAI.xcodeproj
# Set Firebase GoogleService-Info.plist
# Run on simulator (iOS 17+)
```

---

## Production Deployment (Single Droplet)

See **[DEPLOY.md](./DEPLOY.md)** for the full step-by-step guide to deploy on a single DigitalOcean/VPS droplet.

**TL;DR:**
```bash
ssh root@your-droplet
git clone <repo> /opt/medicare && cd /opt/medicare
cp .env.example .env   # fill in real values
DOMAIN=api.yourdomain.com docker compose up -d --build
```

---

## Project Structure

```
medicare/
├── README.md
├── DEPLOY.md                    # Production deployment guide
├── CLAUDE.md                    # AI coding assistant context
├── docker-compose.yml           # Full stack: MongoDB + Backend + Caddy
├── Caddyfile                    # Reverse proxy with auto-HTTPS
├── .env.example                 # Environment template
├── docs/notes/                  # Design docs (architecture, API spec, UX, safety)
├── backend/
│   ├── src/
│   │   ├── main.py              # FastAPI app, CORS, routers, lifespan
│   │   ├── config.py            # Pydantic Settings (env vars)
│   │   ├── api/                 # Route handlers (chat, profile, settings, account)
│   │   ├── ai/                  # AI runtime (stream, prompts, citations, safety, tavily)
│   │   ├── services/            # Business logic (chat, profile, settings, rate limiter)
│   │   ├── dependencies/        # FastAPI deps (auth, database)
│   │   └── models/              # Pydantic request/response models
│   ├── tests/                   # pytest-asyncio tests
│   ├── Dockerfile
│   └── requirements.txt
├── ios/
│   ├── project.yml              # XcodeGen spec
│   ├── MediCareAI/
│   │   ├── Views/               # SwiftUI views
│   │   ├── ViewModels/          # MVVM ViewModels
│   │   ├── Services/            # API, Auth, SSE clients
│   │   ├── Models/              # Codable DTOs
│   │   └── Resources/           # Assets, GoogleService-Info.plist
│   └── MediCareAI.xcodeproj
```

---

## How It Works

```
iOS → Bearer token → FastAPI → Firebase verify_id_token()
→ Load V10 digest + conversation history
→ Build system prompt + user messages
→ Stream Gemini 3.1 Pro via OpenRouter with tavily_search tool
→ Extract citations, detect emergency
→ Save to MongoDB, trigger async V10 update
→ Stream SSE: tool_use → token → done
```

---

## Tests

```bash
cd backend
.venv/bin/python -m pytest tests/ -v                          # Unit tests (40+)
MEDICARE_ENV_FILE=.env.live .venv/bin/python scripts/live_e2e_check.py  # E2E
```
