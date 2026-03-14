# Product Requirements — MediCare AI

**Date**: February 2026
**Phase**: 1 (MVP)
**Audience**: Implementation team

---

## 1. User Personas

### Primary: Margaret, 73
- **Context**: Lives alone, manages hypertension and type 2 diabetes. Takes metformin and lisinopril.
- **Tech comfort**: Uses iPhone for calls, texts, and FaceTime with grandkids. Can download apps from App Store but struggles with complex interfaces.
- **Health behavior**: Googles symptoms but can't tell which results are trustworthy. Often worries about interactions between medications. Doesn't want to bother her doctor with "small" questions.
- **Need**: A simple app where she can type (or later, speak) a question and get a clear, trustworthy answer that knows her health history.
- **Frustrations**: Small text, confusing navigation, AI responses that are vague ("consult your doctor" for everything), having to re-explain her conditions every time.

### Secondary: Robert, 68
- **Context**: Recently retired, active but newly diagnosed with atrial fibrillation. Wife manages most tech but he wants independence.
- **Tech comfort**: Moderate. Uses iPad and iPhone. Prefers large text and clear buttons.
- **Health behavior**: Researches his condition extensively but gets overwhelmed by medical jargon. Wants to understand his treatment options before doctor visits.
- **Need**: Preparation tool for doctor appointments — understand what questions to ask and what his test results mean.

### Secondary: David, 45 (Caregiver — Phase 2+)
- **Context**: Manages health for his 78-year-old mother who has mild cognitive decline.
- **Need**: Oversight of his mother's health questions and responses. Not in Phase 1 scope.

---

## 2. User Journey (Phase 1)

### First-Time User Flow
```
App Store → Download → Launch →
Onboarding (3 screens max):
  1. "Ask any health question, get answers backed by real medical sources."
  2. "We remember your health context to give you personalized answers."
  3. Medical disclaimer acknowledgment (must accept to proceed)
→ Sign Up (email + password) →
→ Optional: Set up V10 digest (conditions, medications, allergies)
→ Home (Chat) → Ask first question → Receive streamed, cited answer
```

### Returning User Flow
```
Launch → Auto-login → Home (Chat) →
  - Start new question, OR
  - Resume previous conversation, OR
  - View/edit V10 health context, OR
  - Adjust settings
```

---

## 3. Feature Specifications

### 3.1 Onboarding

**Purpose**: Build trust, explain the app, collect disclaimer consent.

| Requirement | Detail |
|-------------|--------|
| Screens | Maximum 3 before sign-up |
| Disclaimer | Full medical disclaimer text (see Safety doc). User must tap "I Understand" to proceed. Consent timestamp stored. |
| Skip option | User can skip V10 setup and do it later |
| Re-entry | If app is killed during onboarding, resume from last incomplete step |

**Disclaimer text** (exact wording in `09_SAFETY_AND_COMPLIANCE.md`):
Must communicate that MediCare AI is not a doctor, not a substitute for emergency care, and that users should consult healthcare providers for medical decisions.

### 3.2 Authentication

**Provider**: Firebase Authentication (email/password)

| Flow | Requirements |
|------|-------------|
| Sign Up | Email + password (min 8 chars). Inline validation. Clear error messages. |
| Login | Email + password. "Forgot password?" link. |
| Password Reset | Firebase email reset flow. Confirmation message in app. |
| Logout | Settings → Logout. Confirmation dialog. Clears local session. |
| Session | Firebase ID token with auto-refresh. Silent re-auth on app foreground. |
| Error states | Network error, invalid credentials, email already in use, weak password — each with specific, friendly messages. |

**Auth state management**:
- App checks auth state on every launch.
- If token is valid → go to Home.
- If token is expired → attempt silent refresh.
- If refresh fails → go to Login.

### 3.3 Chat (Core Feature)

**Purpose**: User asks a health question, receives a streamed, citation-backed response.

| Requirement | Detail |
|-------------|--------|
| Input | Text field at bottom of screen. Large font, clear placeholder ("Ask a health question..."). Send button with large tap target. |
| Streaming | Response streams in real-time via SSE. User sees tokens appearing as they're generated. |
| Citations | Inline citation markers [1], [2], etc. Tappable. Each links to citation detail. |
| Citation detail | Shows source name, title, URL (tappable), and relevant snippet. |
| Emergency banner | If response contains emergency flag, show a persistent red banner: "This may be a medical emergency. Call 911." with a tap-to-call action. |
| Confidence | Response includes a confidence indicator (high/medium/low). Shown subtly below the response. |
| Loading state | Typing indicator animation while waiting for first token. Then smooth streaming text. |
| Error state | If request fails: friendly message + retry button. Never show raw error codes. |
| Empty state | First chat shows a warm welcome message with 2-3 example questions the user can tap. |
| Conversation | Messages persist. User can scroll up to see history within the conversation. |

**Example suggested questions** (empty state):
- "What are common side effects of metformin?"
- "I've been having headaches for 3 days. What could it be?"
- "Is it safe to take ibuprofen with blood pressure medication?"

### 3.4 Conversation History

**Purpose**: Users can see and resume past conversations.

| Requirement | Detail |
|-------------|--------|
| List view | Shows conversations sorted by most recent. Title auto-generated from first question. |
| Resume | Tap a conversation → loads full message history → user can continue asking. |
| New chat | Clear "New Chat" button. Starts fresh conversation (V10 context still applied). |
| Pagination | Load 20 conversations at a time. Infinite scroll for more. |
| No delete in Phase 1 | Conversation deletion is Phase 2. |

### 3.5 V10 Digest Memory

**Purpose**: Stores the user's health context so every response is personalized.

**What V10 stores** (free-text digest, structured by the AI):
- Current conditions/diagnoses
- Current medications and dosages
- Known allergies
- Relevant medical history
- Age, relevant demographics

| Requirement | Detail |
|-------------|--------|
| View | Dedicated screen showing current V10 digest in readable format. |
| Edit | User can manually edit the digest text. Save button with confirmation. |
| Auto-update | After each conversation, the AI updates the V10 digest with any new relevant information (new symptoms, new medications mentioned, etc.). User is notified: "Your health profile was updated." |
| Auto-update review | User can see what changed and revert if incorrect. |
| First-time setup | During onboarding, prompt user to enter basic health info. Can skip. |
| Empty state | If no V10 data: "Tell us about your health so we can personalize your answers." with guided prompts. |

**V10 update policy**: See `08_AI_PROMPTS_AND_WORKFLOWS.md` for the exact update algorithm.

### 3.6 Settings

| Setting | Type | Default | Detail |
|---------|------|---------|--------|
| Font size | Segmented control: Regular / Large / Extra Large | Large | Affects all text in the app. Maps to Dynamic Type sizes. |
| High contrast | Toggle | Off | Enables high-contrast color theme. |
| About / Legal | Static screen | — | App version, medical disclaimer, privacy policy, terms. |
| Logout | Button | — | Confirmation dialog → clears session → returns to login. |

### 3.7 Emergency Detection

**Not a separate feature — it's behavior embedded in every chat response.**

When the AI detects emergency symptoms in the user's question or conversation context:
1. Response leads with emergency guidance ("Call 911 immediately").
2. Red emergency banner appears at top of chat.
3. Banner includes a **tap-to-call** button that dials 911 (or configured emergency number).
4. Rest of the response still provides medical information with citations.
5. The `requiresEmergencyCare` flag is set on the message for analytics.

---

## 4. Non-Functional Requirements

### Performance
| Requirement | Target |
|-------------|--------|
| App launch → interactive | < 1.5s |
| First streamed token after send | < 3s (p95) |
| Full response (with web search) | < 15s (p95) |
| Chat scroll | 60fps, no jank |
| Conversation list load | < 500ms |

### Accessibility
| Requirement | Detail |
|-------------|--------|
| Dynamic Type | All text scales, including the largest accessibility sizes |
| VoiceOver | Every screen navigable. All buttons, inputs, and citation markers labeled. |
| Color contrast | WCAG AAA (7:1) for body text, WCAG AA (4.5:1) minimum for all text |
| Tap targets | Minimum 44x44pt for all interactive elements |
| Reduce Motion | Respect system setting. Disable animations when enabled. |

### Reliability
| Requirement | Target |
|-------------|--------|
| Crash-free sessions | >= 99.5% |
| API availability | 99.9% (managed infrastructure) |
| Data durability | MongoDB Atlas with automated backups |
| Auth reliability | Firebase SLA |

---

## 5. Out of Scope (Phase 1)

These are planned for future phases:

| Feature | Phase |
|---------|-------|
| Voice input/output | 2 |
| Image/document upload | 2 |
| Caregiver accounts | 2 |
| HealthKit sync | 2 |
| Push notifications | 2 |
| Multi-language | 2 |
| Offline mode | 3 |
| Apple Watch | 3 |
| Android app | 3 |
| Web dashboard | 3 |

---

## 6. Analytics Events (Track from Day 1)

| Event | Properties | Why |
|-------|-----------|-----|
| `app_launched` | cold/warm, auth_state | Engagement baseline |
| `onboarding_completed` | duration_seconds | Onboarding effectiveness |
| `question_asked` | conversation_id, has_v10_context | Core engagement |
| `response_received` | confidence, has_emergency, citation_count, response_time_ms | Quality monitoring |
| `citation_tapped` | citation_source | Trust indicator |
| `emergency_detected` | symptom_category | Safety system effectiveness |
| `v10_edited` | manual_edit vs auto_update | Personalization adoption |
| `settings_changed` | setting_name, old_value, new_value | Preference insights |
| `error_occurred` | error_type, screen | Reliability tracking |
