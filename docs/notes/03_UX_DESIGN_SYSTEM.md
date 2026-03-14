# UX Design System — MediCare AI

**Date**: February 2026
**Platform**: iOS (SwiftUI)
**Design Philosophy**: Elderly-first, Apple HIG-aligned, medical trust

---

## 1. Design Principles

1. **Calm over clever.** No flashy animations, no gamification. The app should feel like a trusted, quiet assistant.
2. **Readable by default.** If a 73-year-old with presbyopia can't read it without squinting, it's wrong.
3. **One thing at a time.** Each screen does one thing well. No multi-panel dashboards.
4. **Forgiving interaction.** Large tap targets, confirmation dialogs for destructive actions, undo where possible.
5. **Trust through transparency.** Show where answers come from. Never hide the "how" behind the "what."

---

## 2. Color System

### Light Mode (Default)

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#FFFFFF` | Primary background |
| `backgroundSecondary` | `#F5F5F7` | Cards, grouped sections |
| `textPrimary` | `#1D1D1F` | Body text, headings |
| `textSecondary` | `#6E6E73` | Captions, timestamps |
| `accent` | `#0066CC` | Links, buttons, interactive elements |
| `accentPressed` | `#004999` | Button pressed state |
| `userBubble` | `#0066CC` | User message bubble background |
| `userBubbleText` | `#FFFFFF` | User message text |
| `assistantBubble` | `#F0F0F5` | Assistant message bubble background |
| `assistantBubbleText` | `#1D1D1F` | Assistant message text |
| `citationBadge` | `#E8F0FE` | Citation number background |
| `citationBadgeText` | `#0066CC` | Citation number text |
| `emergencyRed` | `#D32F2F` | Emergency banner, critical alerts |
| `emergencyRedText` | `#FFFFFF` | Text on emergency backgrounds |
| `successGreen` | `#2E7D32` | Confirmation, positive states |
| `warningAmber` | `#F57F17` | Caution states |
| `divider` | `#E5E5EA` | Separators |
| `inputBackground` | `#F5F5F7` | Text input fields |
| `inputBorder` | `#D1D1D6` | Text input border |

### Dark Mode

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#000000` | Primary background |
| `backgroundSecondary` | `#1C1C1E` | Cards, grouped sections |
| `textPrimary` | `#F5F5F7` | Body text, headings |
| `textSecondary` | `#8E8E93` | Captions, timestamps |
| `accent` | `#4DA3FF` | Links, buttons |
| `userBubble` | `#0066CC` | User message bubble |
| `assistantBubble` | `#2C2C2E` | Assistant message bubble |
| `emergencyRed` | `#FF453A` | Emergency states |

### High Contrast Mode (User toggle)
- Body text: pure black `#000000` on pure white `#FFFFFF` (light) or vice versa (dark).
- Accent: `#003D99` (light) / `#66B3FF` (dark) for higher contrast.
- All contrast ratios must hit WCAG AAA (7:1 minimum).

### SwiftUI Implementation

```swift
import SwiftUI

extension Color {
    // Define in Asset Catalog with light/dark/high-contrast variants
    static let mcBackground = Color("MCBackground")
    static let mcBackgroundSecondary = Color("MCBackgroundSecondary")
    static let mcTextPrimary = Color("MCTextPrimary")
    static let mcTextSecondary = Color("MCTextSecondary")
    static let mcAccent = Color("MCAccent")
    static let mcUserBubble = Color("MCUserBubble")
    static let mcAssistantBubble = Color("MCAssistantBubble")
    static let mcEmergencyRed = Color("MCEmergencyRed")
    static let mcCitationBadge = Color("MCCitationBadge")
}
```

---

## 3. Typography

### Type Scale

All sizes are **base values** that scale with Dynamic Type. SwiftUI `Font.TextStyle` handles this automatically.

| Style | Font | Base Size | Weight | Line Height | Usage |
|-------|------|-----------|--------|-------------|-------|
| `largeTitle` | SF Pro Display | 34pt | Bold | 41pt | Screen titles |
| `title2` | SF Pro Display | 22pt | Bold | 28pt | Section headers |
| `title3` | SF Pro Display | 20pt | Semibold | 25pt | Card titles |
| `headline` | SF Pro Text | 17pt | Semibold | 22pt | Emphasis, button text |
| `body` | SF Pro Text | 17pt | Regular | 22pt | Primary body text |
| `callout` | SF Pro Text | 16pt | Regular | 21pt | Secondary body text |
| `subheadline` | SF Pro Text | 15pt | Regular | 20pt | Metadata |
| `footnote` | SF Pro Text | 13pt | Regular | 18pt | Timestamps, captions |
| `caption` | SF Pro Text | 12pt | Regular | 16pt | Fine print only |

### Elderly-Specific Rules
- **Minimum body text: 17pt.** Never go smaller for content the user needs to read.
- **Caption/footnote**: Only for non-essential metadata (timestamps). Never for medical content.
- **Line spacing**: Use default SwiftUI line heights (generous). Never compress.
- **Font weight**: Prefer Regular and Semibold. Avoid Light/Thin weights — poor readability for aging eyes.
- **Letter spacing**: Default. Don't tighten.

### Dynamic Type Support

```swift
// ALWAYS use semantic text styles — never hardcoded sizes
Text("Your health question")
    .font(.body) // Scales automatically

Text("Dr. Smith recommends...")
    .font(.headline) // Scales automatically

// For the chat input, ensure it scales but stays reasonable
TextField("Ask a health question...", text: $question)
    .font(.body)
    .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Allow up to accessibility sizes
```

### Testing Checklist
- [ ] Test at Default type size
- [ ] Test at the largest non-accessibility size (xxxLarge)
- [ ] Test at the largest accessibility size (AX5)
- [ ] Verify no text truncation in critical paths
- [ ] Verify layout doesn't break at extreme sizes

---

## 4. Spacing & Layout

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 4pt | Icon-to-text gaps |
| `xs` | 8pt | Tight padding, inline spacing |
| `sm` | 12pt | Compact section gaps |
| `md` | 16pt | Standard padding, inter-element spacing |
| `lg` | 24pt | Section spacing |
| `xl` | 32pt | Major section breaks |
| `xxl` | 48pt | Screen-level vertical breathing room |

### Layout Rules
- **Screen padding**: 16pt horizontal on all screens.
- **Card padding**: 16pt all sides.
- **Message bubble padding**: 12pt horizontal, 10pt vertical.
- **Between messages**: 8pt for same sender, 16pt for sender change.
- **Bottom safe area**: Always respect. Chat input sits above safe area + keyboard.
- **Tap target minimum**: 44x44pt for all interactive elements. No exceptions.

### Content Width
- Max content width: None on iPhone. Text wraps naturally.
- Message bubbles: Max width 85% of screen width. Prevents full-width walls of text.

---

## 5. Component Patterns

### 5.1 Chat Message Bubble

```
┌─────────────────────────────────────┐
│ Based on your symptoms, this could  │
│ be related to your hypertension     │
│ medication [1]. Common side effects │
│ of lisinopril include dizziness     │
│ and headaches [2].                  │
│                                     │
│ I recommend discussing this with    │
│ your doctor at your next visit.     │
│                                     │
│ ┌─────┐ ┌─────┐                    │
│ │ [1] │ │ [2] │  ← tappable badges │
│ └─────┘ └─────┘                    │
│                          2:34 PM   │
└─────────────────────────────────────┘
```

- User bubbles: Right-aligned, accent color background, white text.
- Assistant bubbles: Left-aligned, secondary background, primary text.
- Citation badges: Inline `[1]` markers in the text are tappable. Also shown as chips below the message.
- Timestamp: Footnote size, secondary color, bottom-right.

### 5.2 Emergency Banner

```
┌─────────────────────────────────────┐
│ 🚨 This may be a medical emergency │
│                                     │
│    ┌──────────────────────┐         │
│    │   ☎ Call 911 Now     │         │
│    └──────────────────────┘         │
└─────────────────────────────────────┘
```

- Background: `emergencyRed`
- Text: White, bold, large
- Call button: White background, red text, tappable → opens phone dialer with 911
- Appears at TOP of the response, before medical content
- Cannot be dismissed — stays visible while scrolled to that message

### 5.3 Citation Detail Sheet

Presented as a `.sheet` (bottom sheet) when user taps a citation badge.

```
┌─────────────────────────────────────┐
│ Source [1]                     ✕    │
├─────────────────────────────────────┤
│                                     │
│ Mayo Clinic                         │
│ "Lisinopril Side Effects"           │
│                                     │
│ "Common side effects include        │
│ dizziness, headache, and persistent │
│ cough. Contact your healthcare      │
│ provider if symptoms persist..."    │
│                                     │
│ ┌──────────────────────────┐        │
│ │  Open in Safari  →       │        │
│ └──────────────────────────┘        │
│                                     │
└─────────────────────────────────────┘
```

### 5.4 Chat Input Bar

```
┌─────────────────────────────────────┐
│ ┌──────────────────────┐  ┌──────┐ │
│ │ Ask a health         │  │  ↑   │ │
│ │ question...          │  │ Send │ │
│ └──────────────────────┘  └──────┘ │
└─────────────────────────────────────┘
```

- Text field: Multi-line (grows up to 4 lines, then scrolls). Rounded corners. `body` font.
- Send button: Filled circle or rounded rect. Accent color. 44pt minimum. Disabled when input is empty.
- Keyboard: Moves input bar up. Content scrolls to keep latest messages visible.

### 5.5 Empty Chat State

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│         Welcome, Margaret 👋        │
│                                     │
│    Ask me any health question.      │
│    I'll find reliable sources       │
│    and give you a clear answer.     │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ What are side effects of      │  │
│  │ metformin?                    │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ I've had headaches for 3      │  │
│  │ days — what could it be?      │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Is ibuprofen safe with blood  │  │
│  │ pressure medicine?            │  │
│  └───────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

- Suggested questions are tappable → fills input and sends.

### 5.6 Confidence Indicator

Shown below assistant messages, subtle and non-alarming:

| Level | Display | Color |
|-------|---------|-------|
| High | "Based on strong evidence" | `successGreen` |
| Medium | "Based on available evidence" | `textSecondary` |
| Low | "Limited evidence available — consider consulting your doctor" | `warningAmber` |

### 5.7 V10 Memory Screen

```
┌─────────────────────────────────────┐
│ ← Your Health Profile         Edit  │
├─────────────────────────────────────┤
│                                     │
│ Conditions                          │
│ • Hypertension (diagnosed 2019)     │
│ • Type 2 Diabetes (diagnosed 2021) │
│                                     │
│ Medications                         │
│ • Lisinopril 10mg daily             │
│ • Metformin 500mg twice daily       │
│                                     │
│ Allergies                           │
│ • Penicillin (rash)                 │
│                                     │
│ Other                               │
│ • Age 73, female                    │
│ • Previous knee replacement (2022)  │
│                                     │
│ ┌───────────────────────────────┐   │
│ │ Last updated: Feb 20, 2026   │   │
│ │ Auto-updated after your last  │   │
│ │ conversation                  │   │
│ └───────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

Edit mode: Full-screen text editor with the digest as editable text. Save/Cancel buttons. Confirmation on save.

---

## 6. Navigation Structure

### Tab Bar (3 tabs)

```
┌──────────┬──────────┬──────────┐
│   💬     │   📋     │   ⚙️     │
│   Chat   │  Health  │ Settings │
│          │  Profile │          │
└──────────┴──────────┴──────────┘
```

1. **Chat** (default): New question + conversation history
2. **Health Profile**: V10 digest view and editor
3. **Settings**: Font, contrast, about, logout

### Chat Tab Structure
- Landing: Conversation list (recent chats) + prominent "New Chat" button
- Tap conversation → Chat thread view
- "New Chat" → Empty chat with suggestions

### Navigation Rules
- Use `NavigationStack` (not deprecated `NavigationView`).
- Back buttons: Use system back chevron with custom title.
- No deep nesting: Maximum 2 levels from any tab.
- No hamburger menus. Everything accessible from tabs or one tap from tabs.

---

## 7. Motion & Animation

### Principles
- **Respect Reduce Motion.** Check `UIAccessibility.isReduceMotionEnabled`. When true: instant transitions, no spring animations, no typing indicators.
- **Purposeful only.** Animation exists to communicate state changes, not to delight.

### Allowed Animations
| Where | Animation | Duration |
|-------|-----------|----------|
| Message appear | Fade in + slight slide up | 0.2s ease-out |
| Streaming text | Characters appear (no animation per character — just text update) | Real-time |
| Typing indicator | 3 dots pulsing | Looping, 1s cycle |
| Screen transitions | Default NavigationStack push/pop | System default |
| Sheet present | Default .sheet spring | System default |
| Emergency banner | No animation — appears instantly | Instant |

### Disallowed
- No parallax effects
- No particle effects
- No bouncing/playful animations
- No skeleton screens (use simple loading indicators instead)

---

## 8. Iconography

Use **SF Symbols** exclusively. No custom icon library.

| Usage | SF Symbol | Configuration |
|-------|-----------|--------------|
| Send message | `arrow.up.circle.fill` | .title2, accent color |
| New chat | `plus.circle.fill` | .title2, accent color |
| Back | `chevron.left` | System default |
| Settings | `gearshape.fill` | Tab bar |
| Chat tab | `message.fill` | Tab bar |
| Health profile | `heart.text.square.fill` | Tab bar |
| Citation link | `arrow.up.right.square` | .footnote, accent |
| Emergency call | `phone.fill` | .headline, white |
| Edit V10 | `pencil` | .headline, accent |
| Close sheet | `xmark.circle.fill` | .title3, secondary |
| Error/retry | `arrow.clockwise` | .headline, accent |
| Confidence high | `checkmark.shield.fill` | .footnote, green |
| Confidence medium | `info.circle` | .footnote, secondary |
| Confidence low | `exclamationmark.triangle` | .footnote, amber |

---

## 9. Error States

Every error must be:
1. **Visible** — never silently swallowed.
2. **Calm** — no alarming language, no technical jargon.
3. **Actionable** — always tell the user what to do next.

| Error | Message | Action |
|-------|---------|--------|
| Network offline | "You're not connected to the internet. Check your Wi-Fi or cellular connection." | Retry button |
| API timeout | "This is taking longer than expected. Please try again." | Retry button |
| API error (500) | "Something went wrong on our end. Please try again in a moment." | Retry button |
| Auth token expired | (Silent refresh attempt. If fails:) "Your session expired. Please log in again." | Navigate to login |
| Invalid credentials | "The email or password you entered is incorrect." | Clear password field, focus it |
| Email taken | "An account with this email already exists. Try logging in instead." | Link to login screen |
| Weak password | "Password must be at least 8 characters." | Inline below field |
| Empty question | Send button disabled (no error shown) | — |
| AI model error | "I couldn't generate a response right now. Please try again." | Retry button |

---

## 10. Accessibility Checklist (Per Screen)

Use this for every screen before considering it done:

- [ ] All text uses semantic `Font.TextStyle` (no hardcoded sizes)
- [ ] All interactive elements have `.accessibilityLabel` and `.accessibilityHint`
- [ ] All images/icons have `.accessibilityLabel` or are marked `.accessibilityHidden(true)` if decorative
- [ ] Tab order is logical (VoiceOver reads top-to-bottom, left-to-right)
- [ ] Color is never the sole indicator of state (icons, labels, or shapes also used)
- [ ] Contrast ratio >= 4.5:1 for all text (7:1 for body text in high-contrast mode)
- [ ] All tap targets >= 44x44pt
- [ ] Screen tested at Default, xxxLarge, and AX5 Dynamic Type
- [ ] Screen tested with VoiceOver on — complete flow possible
- [ ] Reduce Motion respected — no custom animations when enabled
- [ ] Keyboard navigation works (for external keyboards)
