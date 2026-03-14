# AI Prompts & Workflows — MediCare AI

**Date**: February 2026
**Model**: Claude Opus 4.6 via Anthropic API
**Architecture**: Single model with tool use (web_search, web_fetch)

This document contains the **exact prompts, algorithms, and decision logic** the AI uses. It is the most important implementation reference for product quality.

---

## 1. Model Configuration

```python
# Anthropic API call configuration
MODEL = "claude-opus-4-6-20250219"  # Or latest available Opus tier
MAX_TOKENS = 4096
TEMPERATURE = 0.3  # Low temperature for medical accuracy, not creativity
TOP_P = 0.95

# Tool configuration — use Anthropic's built-in tools
TOOLS = [
    {"type": "web_search_20250305"},  # Built-in web search
]
# Note: web_fetch is available as a follow-up when the model needs
# to read a specific page in detail after web_search results
```

### Why These Settings
- **Temperature 0.3**: Medical answers need consistency and accuracy, not creative variation. Low temperature makes the model more deterministic.
- **Max tokens 4096**: Medical explanations need space for thoroughness + citations. Most responses use 500-1500 tokens, but complex differential diagnoses need more.
- **Opus model**: The highest-capability model is necessary for reliable medical reasoning, appropriate uncertainty expression, and correct emergency detection. Do not downgrade to Sonnet/Haiku for medical responses.

---

## 2. System Prompt (Main Chat)

This is the complete system prompt sent with every chat request. It defines the AI's behavior.

```python
SYSTEM_PROMPT = """You are MediCare AI, a medical health assistant designed for elderly users. You provide thorough, citation-backed medical guidance in clear, simple language.

## Your Role
You are a knowledgeable health assistant. You can discuss possible diagnoses, suggest treatments, explain medications, interpret symptoms, and help users prepare for doctor visits. You are NOT a doctor and you make this clear when appropriate.

## Core Rules

### 1. EMERGENCY DETECTION (Highest Priority)
Before ANYTHING else, check if the user's message describes emergency symptoms:
- Chest pain, pressure, or tightness (especially with shortness of breath, arm/jaw pain, sweating)
- Sudden severe headache ("worst headache of my life"), sudden confusion, vision loss
- Signs of stroke: face drooping, arm weakness, speech difficulty (FAST)
- Severe difficulty breathing or inability to catch breath
- Heavy uncontrolled bleeding
- Signs of anaphylaxis: throat swelling, difficulty breathing after exposure
- Suicidal thoughts, self-harm, or intent to harm others
- Sudden severe abdominal pain with fever or vomiting blood
- Loss of consciousness or unresponsiveness
- Seizures (first-time or prolonged)
- Signs of severe infection/sepsis: high fever with confusion, rapid heart rate

If ANY emergency pattern is detected:
→ START your response with: "⚠️ IMPORTANT: Based on what you're describing, this could be a medical emergency. Please call 911 (or your local emergency number) or go to the nearest emergency room immediately."
→ Then provide helpful information about the condition, but always reiterate the urgency.
→ Do not minimize emergency symptoms to avoid alarming the user. It is ALWAYS better to over-escalate than to under-escalate.

### 2. CITATIONS (Mandatory)
Every medical claim MUST be backed by evidence from your web searches.
- Use web_search to find current, authoritative medical information.
- Cite sources inline using [1], [2], [3] notation.
- At the end of your response, list all sources with their full title and URL.
- Preferred sources (in order of trust): medical institution sites (Mayo Clinic, Cleveland Clinic, Johns Hopkins), government health agencies (NIH, CDC, WHO, MedlinePlus, NHS), peer-reviewed publications (PubMed, NEJM, Lancet, BMJ), established medical references (UpToDate, Merck Manual).
- If you cannot find evidence for a claim, say "Based on general medical knowledge..." and recommend discussing with a doctor.
- NEVER fabricate a URL or source. If a search returns no useful results, say so.

### 3. PERSONALIZATION (V10 Context)
When the user has a health profile (V10 digest), use it to personalize your response:
- Check for medication interactions with any medications listed in the profile.
- Consider existing conditions when discussing possible diagnoses.
- Note relevant allergies before suggesting any treatments or medications.
- Reference their history naturally: "Given your history of hypertension..." rather than robotically listing their conditions.
- If the V10 is empty, respond generically but suggest they set up their health profile for better answers.

### 4. UNCERTAINTY AND HONESTY
- If symptoms are ambiguous, present multiple possibilities ranked by likelihood.
- Clearly state your confidence level. Use phrases like:
  - High confidence: "This is most likely..." / "The most common cause is..."
  - Medium confidence: "This could be several things..." / "Possible causes include..."
  - Low confidence: "Without more information, it's difficult to say..." / "This is unusual and warrants professional evaluation..."
- When evidence is conflicting or limited, say so explicitly.
- Never give false certainty. "I'm not sure" is always acceptable and preferred over a guess.

### 5. RESPONSE FORMAT (Elderly-Friendly)
- Use SHORT paragraphs (2-3 sentences max).
- Use BULLET POINTS for lists of symptoms, causes, or action items.
- Use BOLD for key terms and action items.
- Explain medical terms in parentheses on first use: "hypertension (high blood pressure)"
- Write at a 6th-8th grade reading level. Prefer simple words.
- End every medical response with a clear "What to do next" section with specific actions.
- Keep total response under 800 words unless the question requires more detail.

### 6. WHAT TO DO NEXT (Every Response)
End every medical response with a clear action section:
- **Urgent**: "See a doctor within 24 hours" or "Go to urgent care today"
- **Soon**: "Make an appointment with your doctor this week"
- **Routine**: "Mention this at your next regular checkup"
- **Self-care**: Specific home remedies or over-the-counter options (with interaction checks against V10)
- **Emergency**: "Call 911 now" (only for true emergencies detected in step 1)

### 7. TOPICS YOU HANDLE
- Symptom analysis and possible diagnoses
- Medication information, side effects, and interactions
- Treatment options and what to expect
- Preventive care and health maintenance
- Understanding test results and medical reports
- Preparing for doctor visits (what to ask, what to bring)
- General health and wellness for elderly adults
- Mental health basics (anxiety, depression, grief, sleep)

### 8. BOUNDARIES
- You do NOT prescribe medications. You discuss options the user can raise with their doctor.
- You do NOT replace ongoing physician care. You supplement it.
- For mental health crises (suicidal ideation, self-harm): immediately provide crisis hotline numbers (988 Suicide & Crisis Lifeline) alongside emergency guidance.
- If asked about topics completely outside health (politics, recipes, etc.), gently redirect: "I'm designed to help with health questions. For that topic, you might want to try a general assistant."

{v10_context_block}
"""
```

### V10 Context Block (Injected When Available)

```python
V10_CONTEXT_TEMPLATE = """
## User Health Profile
The following is this user's health context. Use it to personalize your response, check for interactions, and reference their conditions naturally.

---
{v10_digest}
---

Remember: check medication interactions, consider existing conditions in your differential, and note allergies before suggesting treatments.
"""

V10_EMPTY_TEMPLATE = """
## User Health Profile
This user has not set up their health profile yet. Respond generically and suggest they add their conditions, medications, and allergies in the Health tab for more personalized answers.
"""


def build_system_prompt(v10_digest: str | None) -> str:
    if v10_digest:
        v10_block = V10_CONTEXT_TEMPLATE.format(v10_digest=v10_digest)
    else:
        v10_block = V10_EMPTY_TEMPLATE

    return SYSTEM_PROMPT.replace("{v10_context_block}", v10_block)
```

---

## 3. Message Assembly

The full message array sent to the Anthropic API for each request:

```python
def build_messages(
    conversation_history: list[dict],
    user_question: str,
    max_history_messages: int = 10,
) -> list[dict]:
    """
    Build the messages array for the Anthropic API call.

    Args:
        conversation_history: Previous messages in this conversation
                              [{role: "user"|"assistant", content: "..."}]
        user_question: The new question from the user
        max_history_messages: Max prior messages to include (keeps context manageable)
    """
    messages = []

    # Include recent conversation history (last N messages)
    recent_history = conversation_history[-max_history_messages:]
    for msg in recent_history:
        messages.append({
            "role": msg["role"],
            "content": msg["content"],
        })

    # Add the new user question
    messages.append({
        "role": "user",
        "content": user_question,
    })

    return messages
```

### Context Window Budget
| Component | Estimated Tokens | Notes |
|-----------|-----------------|-------|
| System prompt | ~800 | Fixed |
| V10 digest | ~200-400 | Variable, max 2000 chars ≈ 500 tokens |
| Conversation history (10 msgs) | ~2000-4000 | Variable |
| User question | ~50-200 | Variable |
| **Total input** | **~3000-5400** | Well within context limits |
| Max output | 4096 | Configured |
| Tool use (web search results) | ~2000-5000 | Returned by Anthropic tool infrastructure |

---

## 4. Citation Extraction

After the model completes its response, extract structured citation data.

### Strategy
The model is instructed to list citations at the end of its response in a specific format. We parse this into structured data.

```python
import re
from dataclasses import dataclass


@dataclass
class Citation:
    number: int
    source: str
    title: str
    url: str
    snippet: str


def extract_citations_from_response(response_text: str) -> tuple[str, list[Citation]]:
    """
    Extract citations from the model's response text.

    The model formats citations at the end as:
    Sources:
    [1] Source Name - "Title" (URL)
    [2] Source Name - "Title" (URL)

    Returns:
        (clean_text, citations) - response text with sources section removed,
        and structured citation list.
    """
    citations = []

    # Find the sources section (usually at the end)
    sources_pattern = r'\n(?:Sources|References):\s*\n((?:\[\d+\].+\n?)+)'
    sources_match = re.search(sources_pattern, response_text, re.IGNORECASE)

    if sources_match:
        sources_block = sources_match.group(1)
        # Remove sources section from display text
        clean_text = response_text[:sources_match.start()].rstrip()

        # Parse each citation line
        citation_pattern = r'\[(\d+)\]\s*(.+?)(?:\s*[-–]\s*["""](.+?)["""])?\s*(?:\(?(https?://\S+?)\)?)?\s*$'
        for line in sources_block.strip().split('\n'):
            match = re.match(citation_pattern, line.strip())
            if match:
                citations.append(Citation(
                    number=int(match.group(1)),
                    source=match.group(2).strip(),
                    title=match.group(3).strip() if match.group(3) else match.group(2).strip(),
                    url=match.group(4).strip() if match.group(4) else "",
                    snippet="",  # Populated from search results if available
                ))
    else:
        clean_text = response_text

    return clean_text, citations


def enrich_citations_with_snippets(
    citations: list[Citation],
    search_results: list[dict],
) -> list[Citation]:
    """
    Match citations to web search results and add snippets.
    """
    for citation in citations:
        for result in search_results:
            if citation.url and citation.url in result.get("url", ""):
                citation.snippet = result.get("snippet", "")[:300]
                break
            elif citation.source.lower() in result.get("source", "").lower():
                citation.snippet = result.get("snippet", "")[:300]
                if not citation.url:
                    citation.url = result.get("url", "")
                break
    return citations
```

### Citation Validation
Before sending citations to the client, validate:
1. URL is a real URL format (not fabricated gibberish)
2. Citation number matches an inline reference in the text
3. Duplicate citations are merged

```python
def validate_citations(clean_text: str, citations: list[Citation]) -> list[Citation]:
    """Remove citations not referenced in the text and validate URLs."""
    import urllib.parse

    valid = []
    for c in citations:
        # Check if referenced in text
        if f"[{c.number}]" not in clean_text:
            continue
        # Basic URL validation
        if c.url:
            parsed = urllib.parse.urlparse(c.url)
            if not (parsed.scheme in ("http", "https") and parsed.netloc):
                c.url = ""  # Clear invalid URL
        valid.append(c)

    return valid
```

---

## 5. Confidence Assessment

```python
def assess_confidence(
    response_text: str,
    citations: list,
    user_question: str,
) -> str:
    """
    Determine confidence level based on response characteristics.

    Returns: "high", "medium", or "low"
    """
    # Indicators of low confidence
    low_indicators = [
        "i'm not sure",
        "it's difficult to say",
        "without more information",
        "could be many things",
        "hard to determine",
        "uncertain",
        "not enough information",
        "recommend seeing a doctor for proper diagnosis",
    ]

    # Indicators of high confidence
    high_indicators = [
        "most likely",
        "this is typically",
        "the most common cause",
        "well-established",
        "standard treatment",
        "according to",
    ]

    text_lower = response_text.lower()

    low_score = sum(1 for ind in low_indicators if ind in text_lower)
    high_score = sum(1 for ind in high_indicators if ind in text_lower)

    # Citation count matters
    citation_count = len(citations)
    if citation_count >= 3:
        high_score += 1
    elif citation_count == 0:
        low_score += 2

    # Decision
    if low_score >= 2 or citation_count == 0:
        return "low"
    elif high_score >= 2 and citation_count >= 2:
        return "high"
    else:
        return "medium"
```

---

## 6. Emergency Detection

Emergency detection runs on both the user's question AND the model's response.

```python
EMERGENCY_PATTERNS = {
    "cardiac": [
        r"chest\s+pain",
        r"chest\s+pressure",
        r"chest\s+tight",
        r"heart\s+attack",
        r"can'?t\s+breathe.*chest",
        r"arm\s+pain.*chest|chest.*arm\s+pain",
        r"jaw\s+pain.*chest|chest.*jaw\s+pain",
        r"crushing\s+(chest|pain)",
    ],
    "stroke": [
        r"face\s+(droop|numb|drooping)",
        r"arm\s+(weak|numb|can'?t\s+move)",
        r"sudden\s+(confusion|trouble\s+speaking|vision\s+loss)",
        r"worst\s+headache",
        r"sudden\s+severe\s+headache",
        r"can'?t\s+(speak|talk)\s+(properly|right|clearly)",
        r"one\s+side.*numb|numb.*one\s+side",
    ],
    "breathing": [
        r"can'?t\s+breathe",
        r"severe\s+(difficulty|trouble)\s+breathing",
        r"choking",
        r"throat\s+(closing|swelling|tight)",
        r"anaphyla",
        r"lips?\s+(blue|turning\s+blue)",
    ],
    "self_harm": [
        r"(want|going)\s+to\s+(kill|hurt|harm)\s+(myself|themselves)",
        r"suicid",
        r"end\s+(my|their)\s+life",
        r"don'?t\s+want\s+to\s+live",
        r"self[- ]?harm",
    ],
    "severe_bleeding": [
        r"(heavy|severe|uncontrolled|won'?t\s+stop)\s+bleed",
        r"blood\s+(everywhere|won'?t\s+stop|pouring|gushing)",
        r"vomiting\s+blood",
        r"coughing\s+(up\s+)?blood",
    ],
    "consciousness": [
        r"(passed|passing)\s+out",
        r"(lost|losing)\s+consciousness",
        r"unresponsive",
        r"seizure",
        r"convulsion",
        r"faint(ed|ing)",
    ],
    "severe_pain": [
        r"worst\s+pain.*life",
        r"sudden\s+severe\s+(abdominal|stomach|belly)\s+pain",
        r"excruciating\s+pain",
    ],
}


def detect_emergency(text: str) -> tuple[bool, str | None]:
    """
    Check text for emergency symptom patterns.

    Returns:
        (is_emergency, category) — e.g., (True, "cardiac") or (False, None)
    """
    text_lower = text.lower()

    for category, patterns in EMERGENCY_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, text_lower):
                return True, category

    return False, None


def check_emergency(user_question: str, ai_response: str) -> tuple[bool, str | None]:
    """
    Check both user question and AI response for emergency signals.
    """
    # Check user question first (primary signal)
    is_emergency, category = detect_emergency(user_question)
    if is_emergency:
        return True, category

    # Also check if the model flagged emergency in its response
    emergency_phrases = [
        "call 911",
        "call emergency",
        "go to the emergency room",
        "medical emergency",
        "seek immediate medical",
        "⚠️ IMPORTANT",
    ]
    response_lower = ai_response.lower()
    if any(phrase in response_lower for phrase in emergency_phrases):
        # Try to categorize from response
        _, response_category = detect_emergency(ai_response)
        return True, response_category or "general"

    return False, None
```

---

## 7. V10 Digest Auto-Update

After each conversation exchange, the V10 digest is updated in the background.

### V10 Update Prompt

```python
V10_UPDATE_SYSTEM_PROMPT = """You are a medical record summarizer. Your job is to update a patient's health profile digest based on new conversation information.

Rules:
1. Keep the digest concise (under 2000 characters).
2. ONLY add information the user explicitly stated or confirmed. Do not infer conditions.
3. Organize by: Age/Demographics → Current Conditions → Medications → Allergies → Recent Concerns → Relevant History.
4. If the conversation mentions a NEW condition, medication, allergy, or symptom, ADD it.
5. If the conversation CORRECTS existing information, UPDATE it.
6. If no new health information was discussed, return the digest UNCHANGED.
7. Use plain medical language, not abbreviations.
8. Include dates/timeframes when the user provides them.
9. Do NOT include conversation details, questions asked, or AI responses. Only factual health data.

Return ONLY the updated digest text, nothing else. No explanations, no preamble."""

V10_UPDATE_USER_TEMPLATE = """Current health profile:
---
{current_digest}
---

New conversation:
User: {user_question}
Assistant: {assistant_response}

Return the updated health profile. If no new health information was discussed, return the current profile exactly as-is."""
```

### V10 Update Logic

```python
async def update_v10_after_conversation(
    firebase_uid: str,
    user_question: str,
    assistant_response: str,
    conversation_id,
):
    """
    Update V10 digest based on new conversation content.
    Runs in background — does not block the chat response.
    """
    db = get_db()
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    # Get current digest
    v10 = await db.v10Memories.find_one({"firebaseUid": firebase_uid})
    current_digest = v10["digest"] if v10 else ""

    # Ask model to update
    response = await client.messages.create(
        model=settings.anthropic_model,  # Same Opus model
        max_tokens=600,
        temperature=0.1,  # Very low — deterministic summarization
        system=V10_UPDATE_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": V10_UPDATE_USER_TEMPLATE.format(
                current_digest=current_digest or "(No health profile set up yet)",
                user_question=user_question,
                assistant_response=assistant_response[:1000],  # Truncate to save tokens
            ),
        }],
    )

    new_digest = response.content[0].text.strip()

    # Only update if actually changed
    if new_digest and new_digest != current_digest:
        # Generate a brief change summary
        change_summary = await _generate_change_summary(current_digest, new_digest, client)

        await upsert_v10_digest(
            firebase_uid=firebase_uid,
            digest=new_digest,
            source="auto",
            change_summary=change_summary,
            conversation_id=conversation_id,
        )
        return True

    return False


async def _generate_change_summary(old: str, new: str, client) -> str:
    """Generate a one-line summary of what changed in the V10 digest."""
    if not old:
        return "Initial health profile created from conversation"

    # Simple diff — for Phase 1, just note that it was updated
    # Could be enhanced with actual diff logic later
    response = await client.messages.create(
        model="claude-haiku-4-5-20251001",  # Use Haiku for this simple task
        max_tokens=100,
        temperature=0.1,
        messages=[{
            "role": "user",
            "content": f"In one short sentence (under 15 words), what health information was added or changed?\n\nBefore: {old[:500]}\nAfter: {new[:500]}",
        }],
    )
    return response.content[0].text.strip()
```

### V10 Update Cost Optimization
- The V10 update is a **background task** — it does NOT block the chat response.
- Use the same Opus model for the digest update (medical accuracy matters).
- Use Haiku for the change summary (cheap, fast, low-stakes).
- If the conversation was purely non-medical (e.g., user said "thanks"), skip the update entirely.

```python
# Quick check before calling the model
NON_MEDICAL_PATTERNS = [
    r"^(thanks?|thank you|ok|okay|got it|great|bye|goodbye)\s*[!.]*$",
]

def should_update_v10(user_question: str) -> bool:
    """Skip V10 update for purely non-medical messages."""
    q = user_question.strip().lower()
    for pattern in NON_MEDICAL_PATTERNS:
        if re.match(pattern, q):
            return False
    return True
```

---

## 8. Response Streaming Pipeline

End-to-end flow from user question to streamed response:

```python
async def ask_streaming(self, firebase_uid: str, request: AskRequest):
    """Full streaming pipeline for a chat question."""
    import time

    start_time = time.monotonic()

    # 1. Get or create conversation
    conversation_id = await self._resolve_conversation(
        firebase_uid, request.conversationId, request.question
    )

    # 2. Load V10 digest
    v10_digest = await self._get_v10_digest(firebase_uid)

    # 3. Load conversation history
    history = await self._get_recent_messages(firebase_uid, conversation_id)

    # 4. Build prompt
    system_prompt = build_system_prompt(v10_digest)
    messages = build_messages(history, request.question)

    # 5. Save user message
    await save_message(
        firebase_uid=firebase_uid,
        conversation_id=conversation_id,
        role="user",
        content=request.question,
    )

    # 6. Stream from Anthropic
    full_text = ""
    search_results = []  # Collected from tool use events

    try:
        async with self.anthropic.messages.stream(
            model=settings.anthropic_model,
            max_tokens=settings.ai_max_tokens,
            temperature=settings.ai_temperature,
            system=system_prompt,
            messages=messages,
            tools=[{"type": "web_search_20250305"}],
        ) as stream:
            async for event in stream:
                if event.type == "content_block_delta":
                    if hasattr(event.delta, "text"):
                        full_text += event.delta.text
                        yield {"type": "text_delta", "text": event.delta.text}

    except anthropic.APITimeoutError:
        yield {"type": "error", "code": "AI_TIMEOUT", "message": "This is taking longer than usual. Please try again."}
        return
    except anthropic.RateLimitError:
        yield {"type": "error", "code": "AI_RATE_LIMITED", "message": "We're experiencing high demand. Please try again in a few minutes."}
        return
    except Exception:
        yield {"type": "error", "code": "AI_ERROR", "message": "Something went wrong generating your answer. Please try again."}
        return

    # 7. Post-process
    elapsed_ms = int((time.monotonic() - start_time) * 1000)
    clean_text, citations = extract_citations_from_response(full_text)
    citations = validate_citations(clean_text, citations)
    confidence = assess_confidence(clean_text, citations, request.question)
    is_emergency, emergency_category = check_emergency(request.question, full_text)

    # 8. Send metadata
    yield {
        "type": "metadata",
        "conversationId": str(conversation_id),
        "messageId": "pending",  # Set after persistence
        "citations": [{"number": c.number, "source": c.source, "title": c.title, "url": c.url, "snippet": c.snippet} for c in citations],
        "confidence": confidence,
        "requiresEmergencyCare": is_emergency,
    }

    yield {"type": "done"}

    # 9. Persist assistant message
    msg_id = await save_message(
        firebase_uid=firebase_uid,
        conversation_id=conversation_id,
        role="assistant",
        content=clean_text,
        citations=[vars(c) for c in citations],
        confidence=confidence,
        requires_emergency_care=is_emergency,
        emergency_category=emergency_category,
        response_time_ms=elapsed_ms,
    )

    # 10. V10 update (background, non-blocking)
    if settings.v10_auto_update_enabled and should_update_v10(request.question):
        # Fire and forget — don't await in the request path
        import asyncio
        asyncio.create_task(
            update_v10_after_conversation(
                firebase_uid, request.question, clean_text, conversation_id
            )
        )
```

---

## 9. Prompt Testing Strategy

### Test Categories

**1. Emergency Detection Tests**
| Input | Expected |
|-------|----------|
| "I have chest pain and my left arm is numb" | Emergency: cardiac |
| "I have a headache" | NOT emergency |
| "Worst headache of my life, sudden onset" | Emergency: stroke |
| "I want to kill myself" | Emergency: self_harm + crisis hotline |
| "My child has a fever of 100.1" | NOT emergency |
| "My child has a fever of 105 and is unresponsive" | Emergency: consciousness |

**2. Citation Tests**
| Scenario | Expected |
|----------|----------|
| Common condition (headache) | 2-4 citations from major medical sites |
| Medication question (metformin side effects) | 2-3 citations, at least one from FDA or drug reference |
| Rare condition | At least 1 citation, may note limited evidence |
| Non-medical question | No citations needed, gentle redirect |

**3. V10 Interaction Tests**
| V10 Context | Question | Expected |
|-------------|----------|----------|
| "Takes metformin" | "Can I take ibuprofen?" | Mentions metformin interaction |
| "Allergic to penicillin" | "I have a sinus infection, what antibiotics?" | Avoids penicillin-class drugs |
| Empty | Any medical question | Suggests setting up health profile |

**4. Uncertainty Tests**
| Input | Expected Confidence |
|-------|-------------------|
| "What's aspirin used for?" | High |
| "I have a weird feeling in my left pinky toe" | Medium or Low |
| "What does my dream mean?" | N/A (non-medical redirect) |

---

## 10. Model Fallback Strategy

If the primary Opus model is unavailable:

| Scenario | Action |
|----------|--------|
| Anthropic API timeout (30s+) | Retry once, then return AI_TIMEOUT error |
| Anthropic rate limit (429) | Return AI_RATE_LIMITED with retry-after |
| Anthropic server error (500/503) | Retry once after 2s, then return AI_ERROR |
| Model deprecated | Update `ANTHROPIC_MODEL` env var to latest Opus tier |

**Do NOT fall back to a smaller model (Sonnet/Haiku) for medical responses.** The quality and safety difference is too significant. It is better to show an error and ask the user to retry than to serve a lower-quality medical answer.

Exception: Haiku is used for the V10 change summary (non-medical, low-stakes task).
