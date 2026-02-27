from __future__ import annotations

import json
import re
from collections.abc import Sequence

EMERGENCY_PATTERNS = {
    "cardiac": [
        r"chest\s+pain",
        r"chest\s+pressure",
        r"chest\s+tight",
        r"heart\s+attack",
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
        r"one\s+side.*numb|numb.*one\s+side",
        r"can'?t\s+(speak|talk)\s+(properly|clearly)",
    ],
    "breathing": [
        r"can'?t\s+breathe",
        r"severe\s+(difficulty|trouble)\s+breathing",
        r"choking",
        r"throat\s+(closing|swelling|tight)",
        r"anaphyla",
        r"lips?\s+(blue|turning\s+blue)",
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
        r"collapsed",
        r"seizure",
        r"convulsion",
        r"faint(ed|ing)",
    ],
    "self_harm": [
        r"suicid",
        r"(want|going)\s+to\s+(kill|hurt|harm)\s+(myself|themselves)",
        r"end\s+(my|their)\s+life",
        r"don'?t\s+want\s+to\s+live",
        r"self[- ]?harm",
    ],
    "poisoning": [
        r"overdose",
        r"poison",
        r"swallowed\s+bleach",
        r"took\s+too\s+many\s+pills",
    ],
    "severe_pain": [
        r"worst\s+pain.*life",
        r"sudden\s+severe\s+(abdominal|stomach|belly)\s+pain",
        r"excruciating\s+pain",
    ],
}

_URGENT_PATTERNS = {
    "urgent_fever": [
        r"fever\s+over\s+103",
        r"high\s+fever",
        r"fever\s+won'?t\s+break",
    ],
    "gi_bleeding": [
        r"blood\s+in\s+stool",
        r"black\s+tarry\s+stool",
    ],
    "dehydration": [
        r"can'?t\s+keep\s+anything\s+down",
        r"not\s+urinating",
        r"severe\s+dehydration",
    ],
}

_RESPONSE_EMERGENCY_CUES = [
    r"\bcall\s+911\b",
    r"\bcall\s+(your\s+)?local\s+emergency\s+number\b",
    r"\bgo\s+to\s+(the\s+)?(er|emergency\s+room)\b",
    r"\bmedical\s+emergency\b",
]

_SAFETY_SIGNAL_REGEX = re.compile(
    r"^\s*SAFETY_SIGNAL:\s*(\{[^\n]*\})\s*$",
    re.IGNORECASE | re.MULTILINE,
)

_VALID_CATEGORIES = {
    "cardiac",
    "stroke",
    "breathing",
    "severe_bleeding",
    "consciousness",
    "self_harm",
    "poisoning",
    "severe_pain",
    "general",
    "none",
}


def detect_emergency(text: str) -> tuple[bool, str | None]:
    text_lower = text.lower()

    for category, patterns in EMERGENCY_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, text_lower):
                return True, category

    return False, None


def detect_urgent(text: str) -> tuple[bool, str | None]:
    text_lower = text.lower()
    for category, patterns in _URGENT_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, text_lower):
                return True, category
    return False, None


def requires_crisis_resources(text: str) -> bool:
    text_lower = text.lower()
    return any(re.search(pattern, text_lower) for pattern in EMERGENCY_PATTERNS["self_harm"])


def check_emergency(user_question: str, ai_response: str) -> tuple[bool, str | None]:
    is_emergency, category = detect_emergency(user_question)
    if is_emergency:
        return True, category

    response_lower = ai_response.lower()
    # Do not escalate to emergency banners from generic caution language.
    # Require explicit emergency cues and symptom-level evidence in the response.
    has_explicit_emergency_cue = any(
        re.search(pattern, response_lower) for pattern in _RESPONSE_EMERGENCY_CUES
    )
    if has_explicit_emergency_cue:
        response_is_emergency, response_category = detect_emergency(ai_response)
        if response_is_emergency:
            return True, response_category or "general"

    return False, None


def extract_ai_safety_signal(response_text: str) -> tuple[str, bool, str | None]:
    """Extract AI-emitted safety signal and return cleaned response text.

    Expected line format at the end of the assistant response:
    SAFETY_SIGNAL: {"requiresEmergencyCare": true|false, "category": "cardiac|...|none"}
    """
    matches = list(_SAFETY_SIGNAL_REGEX.finditer(response_text))
    if not matches:
        return response_text.strip(), False, None

    signal_match = matches[-1]
    raw_json = signal_match.group(1)

    requires_emergency = False
    category: str | None = None
    try:
        parsed = json.loads(raw_json)
        raw_requires = parsed.get("requiresEmergencyCare", parsed.get("requires_emergency_care", False))
        raw_category = parsed.get("category", parsed.get("emergencyCategory", "none"))

        requires_emergency = bool(raw_requires)
        category_text = str(raw_category).strip().lower()
        if category_text not in _VALID_CATEGORIES:
            category_text = "general" if requires_emergency else "none"
        category = None if category_text == "none" else category_text
        if not requires_emergency:
            category = None
    except (json.JSONDecodeError, TypeError, ValueError):
        # Invalid signal should never escalate emergency state.
        requires_emergency = False
        category = None

    cleaned = f"{response_text[:signal_match.start()]}{response_text[signal_match.end():]}".strip()
    return cleaned, requires_emergency, category


def assess_confidence(response_text: str, citations: Sequence[object]) -> str:
    text_lower = response_text.lower()

    low_indicators = [
        "i'm not sure",
        "it's difficult to say",
        "without more information",
        "uncertain",
        "not enough information",
        "limited evidence",
    ]

    high_indicators = [
        "most likely",
        "the most common cause",
        "well-established",
        "standard treatment",
        "according to",
    ]

    low_score = sum(1 for token in low_indicators if token in text_lower)
    high_score = sum(1 for token in high_indicators if token in text_lower)

    citation_count = len(citations)
    if citation_count >= 3:
        high_score += 1
    elif citation_count == 0:
        low_score += 2

    if low_score >= 2 or citation_count == 0:
        return "low"
    if high_score >= 2 and citation_count >= 2:
        return "high"
    return "medium"
