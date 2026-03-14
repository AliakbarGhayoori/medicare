# Python Backend Migration Note

**Status**: Historical — for reference only
**Date**: February 2026

---

## Summary

The project backend was originally conceptualized with Node.js/Express/Bun. This was migrated to Python/FastAPI before implementation began.

### Final Decision
- **Runtime**: Python 3.12+
- **Framework**: FastAPI
- **Database Driver**: Motor (async MongoDB)
- **Auth**: Firebase Admin SDK (Python)
- **AI SDK**: `anthropic` Python package

### Rationale
1. Python has the strongest AI/ML ecosystem. The Anthropic SDK, medical NLP libraries, and all major AI tooling are Python-first.
2. FastAPI provides typed APIs with Pydantic, auto-generated OpenAPI docs, and native async support.
3. Motor provides non-blocking MongoDB access, matching FastAPI's async architecture.
4. The team's AI development workflow is Python-centric.

---

## Current Source of Truth

This note is historical only. **Do not use this document for implementation decisions.**

All current implementation guidance is in:
- `00_BASELINE.md` — Canonical decisions
- `05_ARCHITECTURE.md` — System design and code patterns
- `07_API_SPECIFICATIONS.md` — API contracts
- `08_AI_PROMPTS_AND_WORKFLOWS.md` — AI runtime details

Any references to Node.js, Express, Bun, or `z-ai-web-dev-sdk` in older drafts are obsolete and must not be used.
