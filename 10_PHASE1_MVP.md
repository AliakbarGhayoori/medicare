# Phase 1 MVP — MediCare AI

**Duration**: 6-8 weeks
**Date**: February 2026
**Goal**: Ship a high-quality, elderly-first medical assistant with citation-backed answers

---

## 1. Phase 1 Scope

### Must Build
- Firebase auth (sign up, login, logout, password reset)
- Onboarding flow with medical disclaimer acceptance
- Chat with streaming SSE responses
- Citation-backed medical guidance (inline citations + detail view)
- Emergency detection and escalation (red banner + tap-to-call)
- V10 health digest (view, manual edit, auto-update after conversations)
- Conversation history (list, resume, new chat)
- Settings (font size, high contrast toggle, about/legal, logout)
- Account deletion

### Must NOT Build (Phase 1)
- Voice input/output
- Image/file upload
- Caregiver accounts
- HealthKit integration
- Push notifications
- Multi-language support
- Offline mode
- Multi-agent orchestration

---

## 2. Week-by-Week Delivery Plan

### Week 1: Backend Foundation

**Goal**: Secure, running backend skeleton with auth and database.

| Task | Details | Acceptance |
|------|---------|-----------|
| Initialize FastAPI project | Project structure per `05_ARCHITECTURE.md`. `pyproject.toml`, `requirements.txt`, `Dockerfile`, `.env.example`. | `uvicorn src.main:app` starts without errors. |
| Configure MongoDB connection | Motor async client, `get_db()`, connection pool settings. | `GET /health` returns `{"status": "healthy"}` and DB ping succeeds. |
| Create indexes | All indexes from `06_DATABASE_SCHEMA.md`. Run on startup via lifespan. | Indexes verified in MongoDB shell. |
| Firebase Admin auth | Firebase Admin SDK init, `get_current_user_uid` dependency. | Rejects requests without valid token (401). Accepts valid Firebase ID token and returns UID. |
| Structured error handling | Error response envelope. Exception handlers for common cases. | All errors return `{"error": {"code", "message"}}` format. |
| Docker Compose | `docker-compose.yml` with MongoDB + backend services. | `docker compose up` starts both services. |
| Logging | Structured JSON logging. No PHI in logs. | Request logs show method, path, status, latency. No user content. |

**Deliverable**: Backend running locally with auth verification. Any authenticated request reaches a protected route. Docker Compose works.

---

### Week 2: iOS Foundation

**Goal**: Authenticated iOS app shell with navigation.

| Task | Details | Acceptance |
|------|---------|-----------|
| Create Xcode project | SwiftUI app, iOS 17+ target, MVVM structure per `05_ARCHITECTURE.md`. | Project builds and runs on simulator. |
| Firebase iOS SDK | Add firebase-ios-sdk. Configure `GoogleService-Info.plist`. | Firebase initializes on launch without errors. |
| Auth screens | LoginView, SignUpView, ForgotPasswordView. Inline validation, error messages per `03_UX_DESIGN_SYSTEM.md`. | User can sign up, log in, reset password. Errors shown for invalid input. |
| Auth state management | AuthViewModel with `.loading/.authenticated/.unauthenticated` states. Auto-login on launch. Token refresh. | Cold launch → auto-login if session valid. Expired session → login screen. |
| Tab navigation | 3-tab bar (Chat, Health Profile, Settings). NavigationStack per tab. | Tabs switch correctly. Back navigation works. |
| Onboarding flow | 3 onboarding screens + disclaimer acceptance. Show only on first launch. | New user sees onboarding. Disclaimer must be accepted. Returning user skips. |
| Design system setup | Color assets (light/dark/high-contrast), SF Symbols, spacing constants. | Colors adapt to dark mode. High-contrast toggle works. |

**Deliverable**: Authenticated app running on simulator/device. User sees onboarding → signs up → lands on tab bar. No backend API calls yet (placeholder UI).

---

### Week 3: Chat API (Vertical Slice)

**Goal**: Backend handles a full ask-and-answer cycle with streaming, citations, and safety.

| Task | Details | Acceptance |
|------|---------|-----------|
| `POST /api/chat/ask` (SSE) | Full implementation: validate input → load V10 → load history → call Anthropic with streaming → emit SSE events → persist message. | SSE stream delivers tokens incrementally. `done` event includes citations and metadata. |
| System prompt | Exact prompt from `08_AI_PROMPTS_AND_WORKFLOWS.md`. Inject V10 context. | Responses are medical, cited, formatted for elderly reading level. |
| Anthropic SDK integration | `anthropic` Python SDK with streaming. Tool use (web_search). Error handling for API failures/timeouts. | Model uses web_search autonomously. Streams tokens to client. Handles API errors gracefully. |
| Citation extraction | Parse model response for citations. Extract from Sources section. Build citation metadata. | Citations array in `done` event matches inline [N] references. |
| Emergency detection | System prompt detection + backend keyword scan. Set `requiresEmergencyCare` flag. | "Chest pain" → flag true. "Mild headache" → flag false. |
| Confidence assessment | Rule-based assessment from response text + citation count. | Responses with uncertainty language → "low". Strong evidence → "high". |
| `GET /api/chat/history` | List user conversations with pagination. | Returns conversations sorted by most recent. Pagination works. |
| `GET /api/chat/history/{id}` | Get messages for a conversation with pagination. | Returns messages in order. Only returns conversations owned by the authenticated user. |
| Message persistence | Save user + assistant messages to MongoDB. Update conversation metadata. | Messages queryable after save. Conversation `updatedAt` and `messageCount` updated. |

**Deliverable**: `curl` or Postman can send a question and receive a streamed, cited medical response. Full round-trip works: auth → question → streamed answer → persisted.

---

### Week 4: Chat UI

**Goal**: Full chat experience in the iOS app.

| Task | Details | Acceptance |
|------|---------|-----------|
| Chat thread view | Message bubbles (user/assistant), auto-scroll, loading states. | Messages render correctly. New messages auto-scroll to bottom. |
| Streaming text render | Text appears incrementally as SSE tokens arrive. "Searching..." indicator during tool use. | User sees text streaming in real-time. "Searching medical sources..." shown during web search. |
| SSE client | iOS SSE parser using `URLSession.bytes`. Handles all event types. Reconnect on failure. | Stream connects, parses tokens, handles `done` event with metadata. |
| Citation badges | Inline `[1] [2]` in message text are tappable. Citation chips below message. | Tapping citation opens detail sheet. |
| Citation detail sheet | Bottom sheet with source name, title, snippet, "Open in Safari" link. | Sheet opens/closes. Safari link works. |
| Emergency banner | Red banner at top of response with "Call 911" button. | Banner shows for emergency responses. Tap-to-call opens phone dialer. |
| Confidence indicator | Subtle text below assistant messages per `03_UX_DESIGN_SYSTEM.md`. | High/medium/low shown with appropriate color. |
| Chat input bar | Multi-line text field + send button. Disabled when empty. Keyboard handling. | Input grows to 4 lines. Send button enabled/disabled correctly. Keyboard moves input bar up. |
| Empty chat state | Welcome message + 3 tappable suggested questions. | Tapping a suggestion fills input and sends. |
| Conversation list | List of past conversations. Tap to resume. "New Chat" button. | Conversations load with titles and previews. Tap resumes correctly. |
| Error states | Network error, timeout, AI error — each with friendly message + retry. | All error states show appropriate message and retry works. |

**Deliverable**: User can open the app, start a conversation, see a streamed response with citations, tap citations for details. Can view conversation history and resume past chats.

---

### Week 5: V10 + Settings

**Goal**: Personalization and user preferences work end-to-end.

| Task | Details | Acceptance |
|------|---------|-----------|
| `GET /api/profile/v10` | Return user's V10 digest. | Returns digest or null for new users. |
| `PUT /api/profile/v10` | Update digest (manual edit). Validate input. | Saves new digest. Increments version. Sets `lastUpdateSource: "manual"`. |
| V10 auto-update | After each chat response, run V10 update prompt (async). Save if changed. | New health info mentioned in chat appears in V10 after conversation. |
| V10 memory screen (iOS) | Display current digest in readable format. "Edit" button. | Digest renders with clear formatting. Edit button navigates to editor. |
| V10 editor (iOS) | Full-screen text editor. Save/Cancel. Confirmation on save. | User can edit and save. API call succeeds. Confirmation shown. |
| V10 auto-update notification | After auto-update, show subtle banner: "Your health profile was updated." | User sees update notification. Can tap to view changes. |
| `GET /api/settings` | Return user settings. | Returns current font size, contrast, disclaimer status. |
| `PUT /api/settings` | Partial update of settings. | Updates only provided fields. Returns full settings. |
| `POST /api/settings/accept-disclaimer` | Record disclaimer acceptance. | Stores version + timestamp. |
| Settings screen (iOS) | Font size control, high contrast toggle, about, logout. | Font size changes apply globally. High contrast toggles. Logout works with confirmation. |
| `DELETE /api/account` | Delete all user data + Firebase account. | All data deleted. User returned to login. Cannot log back in without re-registering. |
| Account deletion UI | Settings → Delete Account. Type "DELETE" to confirm. | Confirmation flow works. Account deleted. |

**Deliverable**: Full personalization loop: V10 is used in chat responses, auto-updated after conversations, and manually editable. Settings work. Account deletion works.

---

### Week 6: Hardening & Quality

**Goal**: App meets Apple-quality and safety standards.

| Task | Details | Acceptance |
|------|---------|-----------|
| Accessibility audit | Dynamic Type (all sizes including AX5). VoiceOver labels. Contrast ratios. Tap targets. | Passes checklist in `03_UX_DESIGN_SYSTEM.md` Section 10 for every screen. |
| Safety regression tests | All emergency test cases from `09_SAFETY_AND_COMPLIANCE.md` Section 8. | 100% of emergency cases correctly flagged. All citations present. |
| Unit tests (backend) | Prompt assembly, citation extraction, emergency detection, confidence assessment, V10 update logic. | All tests pass. |
| Integration tests (backend) | Auth flow, chat ask end-to-end, conversation history, V10 CRUD, settings CRUD, account deletion. | All tests pass with test database. |
| UI tests (iOS) | Auth flow, send question and receive response, open citation, edit V10, change settings. | All UI test scenarios pass on simulator. |
| Performance tuning | Measure streaming latency. Optimize MongoDB queries. Profile iOS rendering. | First token < 3s (p95). Chat scroll 60fps. Conversation list < 500ms. |
| Logging and monitoring | Structured logs for all request paths. Error tracking. | Logs are queryable. Errors are visible. |
| Security review | Token validation, CORS, input validation, no PHI in logs, secrets management. | Passes security checklist in `05_ARCHITECTURE.md` Section 8. |

**Deliverable**: Hardened app with full test coverage on critical paths. All quality gates passing.

---

### Week 7-8: Polish & Ship

**Goal**: Release-quality app ready for TestFlight and App Store submission.

| Task | Details | Acceptance |
|------|---------|-----------|
| UX polish | Animation timing, loading states, edge case UIs, empty states. | No visual glitches. All states look intentional. |
| Bug fixes | Fix all P0/P1 defects found during Week 6. | Zero P0/P1 defects remaining. |
| TestFlight deployment | Build → TestFlight → internal testing cohort. | App installs and runs correctly via TestFlight. |
| Elderly user testing | 3+ elderly test users complete onboarding → first answer flow. | All complete within 5 minutes. Feedback incorporated. |
| Backend production deploy | Deploy to staging → full regression → deploy to production. | All tests pass in staging. Production is stable. |
| App Store preparation | App name, description, screenshots, privacy labels, age rating, review notes. | All App Store Connect fields completed. |
| App Store submission | Submit for review. | Build submitted. Review notes explain medical disclaimer and AI usage. |

**Deliverable**: App submitted to App Store. Production backend running and monitored.

---

## 3. Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Anthropic API latency spikes | Users wait too long | Medium | Streaming mitigates perceived latency. Timeout at 30s with friendly error. |
| Citation quality issues | Users lose trust | Medium | System prompt mandates citations. Backend validates presence. Manual review of sample responses weekly. |
| Emergency detection misses | Safety failure | Low | Dual-layer detection (model + keyword scan). Comprehensive test suite. Regular scenario testing. |
| Firebase Auth downtime | Users can't log in | Low | Firebase SLA is 99.95%. Graceful error messages. |
| MongoDB Atlas downtime | API unavailable | Low | Atlas SLA is 99.95%. Health check endpoint for monitoring. |
| App Store rejection | Delayed launch | Medium | Pre-review: follow Apple health app guidelines, clear disclaimers, accurate privacy labels. |
| Cost overruns from API usage | Financial | Medium | Rate limiting (30 req/hour/user). Monitor usage daily. Alert at 80% of budget. |

---

## 4. Phase 1 Acceptance Gates (Must All Pass)

### Product Gates
- [ ] New elderly user completes onboarding → first answer in < 5 minutes (3+ test users)
- [ ] 100% of medical claims in responses have citations (verified on 20+ test questions)
- [ ] All emergency test scenarios correctly escalated
- [ ] Responses at 6th-8th grade reading level (verified on sample set)

### Engineering Gates
- [ ] First streamed token < 3s (p95) in staging
- [ ] >= 99.5% crash-free sessions in TestFlight cohort
- [ ] All critical flows have end-to-end tests (auth, chat, V10, settings, account deletion)
- [ ] CI pipeline passing: lint + type checks + unit tests + integration tests

### Quality Gates
- [ ] Accessibility audit pass (Dynamic Type, VoiceOver, contrast, tap targets)
- [ ] Zero P0/P1 defects in release candidate
- [ ] Security checklist complete
- [ ] App Store readiness checklist complete
- [ ] Safety regression suite passes
