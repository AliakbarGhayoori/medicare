# MediCare AI

**A trusted, citation-backed medical assistant for elderly users.**

Native iOS app + Python FastAPI backend, powered by a single Opus-class AI model with real-time web evidence retrieval.

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
| Database | MongoDB (Atlas in production, Docker locally) |
| AI Model | Claude Opus 4.6 via Anthropic API, single-model path with tool use |
| AI Tools | Tavily search via model function-calling for real-time medical evidence |
| Streaming | Server-Sent Events (SSE) for real-time response delivery |
| Auth | Firebase Authentication (email/password) |
| Deployment | Docker Compose (dev), managed containers (prod) |

---

## Document Index

### Source of Truth
| # | Document | Purpose |
|---|----------|---------|
| 00 | [Baseline v3.0](./00_BASELINE.md) | Canonical decisions — resolves all conflicts |

### Product
| # | Document | Purpose |
|---|----------|---------|
| 01 | [Executive Summary](./01_EXECUTIVE_SUMMARY.md) | Vision, market context, success metrics |
| 02 | [Product Requirements](./02_PRODUCT_REQUIREMENTS.md) | User stories, acceptance criteria, feature specs |
| 03 | [UX Design System](./03_UX_DESIGN_SYSTEM.md) | Colors, typography, components, accessibility |

### Engineering
| # | Document | Purpose |
|---|----------|---------|
| 05 | [Architecture](./05_ARCHITECTURE.md) | System design, runtime flow, streaming, error handling |
| 06 | [Database Schema](./06_DATABASE_SCHEMA.md) | Collections, indexes, migrations, retention |
| 07 | [API Specifications](./07_API_SPECIFICATIONS.md) | Every endpoint with contracts, errors, examples |

### AI & Safety
| # | Document | Purpose |
|---|----------|---------|
| 08 | [AI Prompts & Workflows](./08_AI_PROMPTS_AND_WORKFLOWS.md) | System prompts, citation logic, V10 update algorithm |
| 09 | [Safety & Compliance](./09_SAFETY_AND_COMPLIANCE.md) | Medical disclaimers, emergency detection, privacy |

### Delivery
| # | Document | Purpose |
|---|----------|---------|
| 10 | [Phase 1 MVP](./10_PHASE1_MVP.md) | Week-by-week plan, deliverables, acceptance gates |
| 20 | [Deployment & Testing](./20_DEPLOYMENT_AND_TESTING.md) | Environments, CI/CD, test strategy, monitoring |

### Historical
| # | Document | Purpose |
|---|----------|---------|
| — | [Python Migration Note](./PYTHON_UPDATE.md) | Why we moved from Node/Express to Python (historical only) |

---

## Quick Start (Development)

```bash
# 1. Clone and enter
git clone <repo-url> && cd medicare

# 2. Backend
cp .env.example .env  # fill in Firebase + Anthropic/OpenRouter + Tavily keys
docker compose up -d mongo
cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --port 8000

# 3. iOS
open ios/MediCareAI.xcodeproj
# Set Firebase GoogleService-Info.plist
# Run on simulator (iOS 17+)
```

---

## Project Structure (Target)

```
medicare/
├── README.md
├── docs/                    # All documentation (this folder can hold docs)
├── backend/
│   ├── src/
│   │   ├── api/             # Route handlers
│   │   ├── services/        # Business logic
│   │   ├── ai/              # Model runtime, prompts, citation extraction
│   │   ├── db/              # Mongo connection and helpers
│   │   ├── dependencies/    # FastAPI dependencies (auth, context)
│   │   ├── models/          # Pydantic models
│   │   └── main.py          # App entry point
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
├── ios/
│   ├── MediCareAI/
│   │   ├── Views/           # SwiftUI views
│   │   ├── ViewModels/      # ObservableObject VMs
│   │   ├── Services/        # API client, Firebase auth
│   │   ├── Models/          # Codable data models
│   │   └── Resources/       # Assets, fonts, configs
│   └── MediCareAI.xcodeproj
├── docker-compose.yml
├── .env.example
└── .github/
    └── workflows/           # CI/CD pipelines
```

---

## Phase 1 Scope (6-8 Weeks)

**Build:** Auth, chat with citations, V10 memory, settings, emergency detection.
**Skip:** Voice, uploads, caregivers, HealthKit, multi-agent orchestration.

See [Phase 1 MVP](./10_PHASE1_MVP.md) for the detailed week-by-week plan.

---

## Quality Bar

This app targets **Apple-level quality**:
- HIG-aligned, elderly-first UI with large text and high contrast
- Every medical claim backed by a verifiable citation
- Emergency symptoms detected and escalated immediately
- Accessibility audit (Dynamic Type, VoiceOver, contrast ratios)
- p95 response time under budget, 99.5%+ crash-free sessions
