# Executive Summary — MediCare AI

**Date**: February 2026
**Platform**: Native iOS (SwiftUI) + Python FastAPI backend
**AI**: Claude Opus 4.6 with real-time web evidence

---

## The Problem

Elderly users face three compounding barriers when seeking health guidance online:

1. **Interface complexity.** Generic AI assistants (ChatGPT, Google search) assume tech-literate users. Small text, dense layouts, and multi-step flows frustrate elderly people.
2. **Trust deficit.** AI health answers often lack sources. Users can't tell whether guidance is backed by Mayo Clinic or hallucinated. This erodes trust in a domain where trust is existential.
3. **No personalization.** Every session starts from zero. The AI doesn't know the user's conditions, medications, or history, so answers are generic and sometimes dangerous (e.g., suggesting medications that interact with existing prescriptions).

### Market Context
- 55M+ Americans are 65+, growing to 80M+ by 2040.
- 80% of elderly adults have at least one chronic condition; 68% have two or more.
- Elderly users are the fastest-growing smartphone demographic but the most underserved by AI products.
- Existing health apps (WebMD, Ada Health, Babylon) either lack AI depth or aren't designed for elderly accessibility.

---

## The Solution

MediCare AI is a **native iOS medical assistant** purpose-built for elderly users. It combines:

- **One simple action**: Ask a health question in plain language.
- **Citation-backed answers**: Every medical claim links to a verifiable source (Mayo Clinic, NIH, PubMed, etc.).
- **Persistent health context**: V10 digest memory stores conditions, medications, allergies, and history so every answer is personalized.
- **Emergency detection**: Critical symptoms (chest pain, stroke signs, severe bleeding) trigger immediate "Call 911" guidance before anything else.
- **Elderly-first design**: Large text, high contrast, simple navigation, VoiceOver support, and forgiving interaction patterns.

### What Makes This Different
| Feature | MediCare AI | Generic AI Chat | Health Apps (WebMD/Ada) |
|---------|-------------|----------------|------------------------|
| Citations on every claim | Yes | No | Partial |
| Persistent health context | V10 digest | None | Basic profiles |
| Emergency detection | Real-time in every response | No | Symptom checkers only |
| Elderly-optimized UI | Purpose-built | No | No |
| Full diagnostic reasoning | Yes (Opus-class model) | Varies | Rule-based |
| Streaming responses | Yes (SSE) | Some | No |

---

## Strategic Decisions

### 1. Native iOS First (Not Web, Not Cross-Platform)
- SwiftUI gives the best performance and accessibility stack for elderly users.
- App Store distribution builds trust (review process, familiar install pattern).
- Native integration path for future HealthKit, Siri, and accessibility features.
- **Trade-off accepted**: No Android or web in Phase 1. iOS-first lets us ship faster and higher quality.

### 2. Python/FastAPI Backend (Not Node)
- Python has the strongest AI/ML ecosystem. Anthropic SDK, LangChain (if needed later), and all medical NLP libraries are Python-first.
- FastAPI gives typed APIs, async support, auto-generated OpenAPI docs, and Pydantic validation.
- Motor (async MongoDB driver) provides non-blocking database access.
- **Trade-off accepted**: Slightly higher memory per process than Node. Acceptable for our scale.

### 3. Single Opus-Class Model (Not Multi-Agent)
- Multi-agent adds 2-5x latency and exponential failure modes.
- A single Opus-class model with tool use (web_search, web_fetch) handles the full pipeline: understanding, evidence gathering, reasoning, citation formatting, and safety checks.
- **Trade-off accepted**: Higher per-request cost. Worth it for quality and simplicity. We can optimize later with caching and prompt engineering.

### 4. Full Diagnostic Guidance (Not Just Triage)
- Users want real answers, not "see a doctor" for everything.
- The model provides differential diagnoses, treatment suggestions, medication information, and specialist recommendations.
- **Trade-off accepted**: Higher liability surface. Mitigated by mandatory citations, uncertainty disclosure, emergency detection, and clear disclaimers.

---

## Phase 1 Outcomes

### Ships
- Authentication (email/password via Firebase)
- Chat with streaming, citation-backed medical responses
- V10 digest memory (view, edit, auto-update)
- Emergency detection and escalation
- Conversation history
- Settings (font size, contrast)
- Onboarding with medical disclaimer

### Does Not Ship (Phase 1)
- Voice input/output
- File/image upload
- Caregiver accounts
- HealthKit integration
- Push notifications
- Multi-language support

---

## Success Metrics

### Phase 1 Launch Criteria
| Metric | Target |
|--------|--------|
| Time to first answer | < 5 min for new elderly user (onboarding → first response) |
| Citation coverage | 100% of medical claims have a verifiable source |
| Emergency detection | 100% of red-flag test scenarios escalated correctly |
| Crash-free sessions | >= 99.5% in TestFlight cohort |
| First streamed token | < 3s (p95) |
| Defect bar | Zero P0/P1 at release candidate |

### Post-Launch KPIs (Track from Day 1)
| Metric | Why It Matters |
|--------|---------------|
| Daily active users | Adoption signal |
| Questions per session | Engagement depth |
| Citation tap-through rate | Trust indicator |
| Emergency escalation rate | Safety system working |
| V10 digest edit rate | Personalization adoption |
| Session duration | Engagement (but watch for confusion signals) |
| App Store rating | Overall product quality |

---

## Cost Model (Estimates)

### Per-Request Cost (Phase 1)
| Component | Estimated Cost |
|-----------|---------------|
| Claude Opus 4.6 (~2K input + ~1K output tokens) | ~$0.04-0.08 per request |
| Web search tool use (~2-3 searches per request) | Included in Anthropic pricing |
| MongoDB Atlas (shared tier) | ~$0/month (free tier) to ~$57/month (M10) |
| Firebase Auth | Free up to 10K monthly active users |
| Hosting (container) | ~$20-50/month |

### Monthly Estimate at Scale
| Users (MAU) | Est. Questions/Month | Est. AI Cost/Month |
|-------------|---------------------|-------------------|
| 100 | 3,000 | ~$150-240 |
| 1,000 | 30,000 | ~$1,500-2,400 |
| 10,000 | 300,000 | ~$15,000-24,000 |

> These are rough estimates. Actual costs depend on response length, search frequency, and caching effectiveness. Caching common medical queries can reduce costs 20-40%.

---

## Implementation Readiness

All decisions are locked. Documentation is complete. The project is ready to begin Phase 1 implementation with week-by-week delivery.

**Start with**: Backend skeleton (FastAPI + auth + MongoDB) → iOS skeleton (SwiftUI + auth flow) → Chat vertical slice.

See [Phase 1 MVP](./10_PHASE1_MVP.md) for the detailed plan.
