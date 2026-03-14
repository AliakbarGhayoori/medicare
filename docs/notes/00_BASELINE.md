# MediCare AI — Canonical Baseline (v3.0)

**Date**: February 20, 2026
**Status**: Approved — source of truth for all implementation decisions
**Supersedes**: v2.2 baseline and all prior docs

> If any other document contradicts this file, **this file wins**.

---

## 1. Product Identity

MediCare AI is a **native iOS medical assistant for elderly users**. It provides **full diagnostic and treatment guidance** grounded in real-time web evidence, delivered through a simple chat interface designed for accessibility.

### Core Value Proposition
- **Trusted**: Every medical claim cites a verifiable source.
- **Safe**: Emergency symptoms are detected and escalated immediately.
- **Personal**: V10 digest memory gives the AI the user's full health context.
- **Simple**: One primary action — ask a health question and get a clear answer.

### What This App Is NOT
- Not a licensed clinician, medical device, or FDA-regulated product.
- Not a substitute for emergency services (911/local emergency number).
- Not a replacement for an ongoing relationship with a physician.

---

## 2. Platform & Stack (Locked)

### iOS Client
| Decision | Value |
|----------|-------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Minimum iOS | 17.0 |
| Architecture | MVVM |
| Auth SDK | Firebase Auth (email/password) |
| Networking | URLSession with async/await |
| Streaming | SSE (Server-Sent Events) via `AsyncBytes` |

### Backend
| Decision | Value |
|----------|-------|
| Language | Python 3.12+ |
| Framework | FastAPI |
| Database | MongoDB via Motor (async driver) |
| Auth Verification | Firebase Admin SDK |
| HTTP Client | httpx (async) |
| Validation | Pydantic v2 |
| Streaming | `StreamingResponse` with SSE format |
| Process Manager | uvicorn with gunicorn (production) |

### AI Runtime
| Decision | Value |
|----------|-------|
| Model | Claude Opus 4.6 (or latest Opus tier) via Anthropic API |
| SDK | `anthropic` Python SDK |
| Tools | `web_search`, `web_fetch` (Anthropic built-in tool use) |
| Architecture | **Single-model, single-request path** — no multi-agent orchestration |
| Streaming | Model streams tokens → backend SSE → iOS incremental render |
| Context | System prompt + V10 digest + recent conversation + user question |
| Citations | Extracted from web_search/web_fetch tool results, formatted inline |

### Why Single-Model (No Multi-Agent)
Multi-agent orchestration adds latency, complexity, and failure modes. For Phase 1 (and likely beyond), a single Opus-class model with tool use handles the entire pipeline:
1. Understands the medical question
2. Decides what evidence to search for
3. Searches the web and fetches relevant pages
4. Synthesizes an answer with citations
5. Applies safety checks and emergency detection

This is simpler, faster, and more reliable than chaining multiple models.

---

## 3. AI Policy (Locked)

### Medical Capability
- **Full diagnosis and treatment guidance is in scope.** The model may discuss possible conditions, suggest treatments, and explain medications.
- **Uncertainty must be explicit.** When evidence is weak or symptoms are ambiguous, the model must say so.
- **Emergency detection is mandatory.** Chest pain, stroke symptoms, severe bleeding, suicidal ideation, and other critical patterns trigger immediate escalation.
- **Citations are mandatory.** Every medical claim in the response must reference a specific source. No fabricated URLs or sources.

### Prompt Architecture
The system prompt is the core of the product. It defines:
1. The AI's role and boundaries
2. Medical reasoning approach
3. Citation requirements
4. Emergency detection behavior
5. Response formatting for elderly readability
6. How to use V10 digest context

Full prompt text is specified in `08_AI_PROMPTS_AND_WORKFLOWS.md`.

### Response Quality Standards
- Written at a **6th-8th grade reading level** (Flesch-Kincaid)
- Short paragraphs, bullet points preferred
- Medical terms explained in plain language on first use
- Clear action items ("See a doctor within 24 hours", "Call 911 now")

---

## 4. Safety & Compliance (Locked)

### Required Safety Behaviors
1. **Medical disclaimer** shown during onboarding and accessible at all times.
2. **Emergency detection** for critical symptom patterns — response must lead with "Call 911" or local emergency guidance.
3. **Uncertainty disclosure** — never claim certainty when evidence is weak.
4. **Doctor follow-up** — encourage professional consultation for anything beyond minor/well-understood conditions.
5. **No fabricated citations** — if the model can't find evidence, it must say so rather than inventing sources.

### Privacy Baseline
- All traffic over HTTPS/TLS.
- Firebase token verification on every protected endpoint.
- MongoDB connection authenticated and encrypted.
- No PHI in application logs (redact before logging).
- Secrets stored in environment variables or a managed secret store, never in code.
- User data export and deletion capability (required for App Store and privacy compliance).

### Compliance Positioning
- **Not HIPAA-covered**: We are not a covered entity or business associate. We don't process insurance claims or maintain medical records in the HIPAA sense.
- **Privacy-forward**: We follow privacy best practices as a consumer app (Apple App Privacy, data minimization).
- **Disclaimer-first**: Every user sees and acknowledges the medical disclaimer before first use.

---

## 5. Apple-Quality Standards (Locked)

### UX Non-Negotiables
- **HIG alignment**: Native iOS navigation, controls, and interaction patterns.
- **Elderly-first design**: Large text (minimum 17pt body), high contrast (WCAG AAA target), large tap targets (minimum 44pt).
- **Dynamic Type**: Full support including the largest accessibility sizes.
- **VoiceOver**: Every interactive element labeled. Full screen reader navigation flow tested.
- **Error recovery**: Every error state has a clear, calm message and an obvious recovery action.

### Engineering Non-Negotiables
- **Typed contracts**: Pydantic models on backend, Codable on iOS. No untyped dictionaries crossing boundaries.
- **Streaming**: All chat responses streamed via SSE. No user stares at a spinner for 10+ seconds.
- **Structured error handling**: Consistent error envelope on all API responses. No raw 500s reaching the client.
- **Automated testing**: Unit tests for critical logic, integration tests for API flows, UI tests for core user journeys.
- **CI enforcement**: Lint, type checks, tests, and performance smoke tests run on every PR.

### Performance Budgets
| Metric | Budget |
|--------|--------|
| Time to first streamed token | < 3s (p95) |
| Full response completion | < 15s (p95) including web search |
| API cold start | < 2s |
| iOS app launch to interactive | < 1.5s |
| Crash-free sessions | >= 99.5% |

---

## 6. Phase 1 Scope (Locked)

### Included
- Firebase auth (email/password, sign up, login, logout, password reset)
- Chat interface with streaming responses
- Citation-backed medical guidance with inline source references
- Citation detail view (tap a citation to see the full source)
- V10 digest memory (view, edit, auto-update after conversations)
- Settings (font size, high contrast toggle)
- Emergency detection and escalation in responses
- Onboarding flow with medical disclaimer acknowledgment
- Conversation history (list and resume past chats)

### Excluded from Phase 1
- Voice input/output
- File/image upload and document parsing
- Caregiver/family member accounts
- Multi-agent orchestration
- HealthKit integration
- Push notifications
- Offline mode (queued messages)
- Localization (English only for Phase 1)

---

## 7. Phase 1 Acceptance Gates

A phase ships **only** when all gates pass.

### Product Gates
| Gate | Criteria |
|------|----------|
| Elderly usability | New user completes onboarding → first answer in < 5 minutes (tested with 3+ elderly users) |
| Citation coverage | 100% of medical claims in assistant responses have a citation |
| Emergency handling | All red-flag test scenarios correctly trigger emergency guidance |
| Readability | Responses verified at 6th-8th grade reading level in test set |

### Engineering Gates
| Gate | Criteria |
|------|----------|
| Streaming | First token delivered in < 3s (p95) in staging environment |
| Stability | >= 99.5% crash-free sessions in TestFlight cohort |
| Test coverage | All critical flows (auth, chat, V10, settings) have end-to-end tests |
| CI green | All lint, type, test, and performance checks pass |

### Quality Gates
| Gate | Criteria |
|------|----------|
| Accessibility | Dynamic Type audit pass, VoiceOver navigation verified, contrast ratios checked |
| Defect bar | Zero P0 or P1 defects in release candidate |
| App Store | App Store metadata, screenshots, privacy labels, and review guidelines checklist complete |
| Safety regression | Full safety test suite passes (emergency detection, uncertainty, citation validity) |

---

## 8. Naming & Convention Standards

### API/Database Field Names
External contracts (API JSON, MongoDB documents) use **camelCase**:
- `firebaseUid`, `conversationId`, `createdAt`, `updatedAt`, `requiresEmergencyCare`

### Python Internals
Python code uses **snake_case** per PEP 8:
- `firebase_uid`, `conversation_id`, `created_at`
- Translation happens at Pydantic model boundaries using `alias` or `by_alias`.

### Swift
Swift code uses **camelCase** naturally, matching the API contract.

### File Naming
- Documentation: `XX_TITLE.md` (numbered, uppercase, no spaces)
- Python: `snake_case.py`
- Swift: `PascalCase.swift`

---

## 9. Documentation Governance

- **This file is the source of truth.** All other docs must align.
- Any change to locked decisions requires an explicit version bump (v3.1+) and documented rationale.
- Missing information should be added to the appropriate topic document, not to this baseline.
