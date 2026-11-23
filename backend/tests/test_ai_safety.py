from __future__ import annotations

from src.ai.safety import (
    SafetySignalFilter,
    assess_confidence,
    check_emergency,
    detect_emergency,
    extract_ai_safety_signal,
    requires_crisis_resources,
    resolve_emergency,
)


def test_detect_emergency_positive() -> None:
    is_emergency, category = detect_emergency("I have crushing chest pain and arm numbness")
    assert is_emergency is True
    assert category == "cardiac"


def test_detect_emergency_negative() -> None:
    is_emergency, category = detect_emergency("I have mild knee pain when walking")
    assert is_emergency is False
    assert category is None


def test_check_emergency_from_response_language() -> None:
    detected, category = check_emergency(
        user_question="I feel unwell",
        ai_response=(
            "This may be a medical emergency with chest pain and trouble breathing. Call 911 now."
        ),
    )
    assert detected is True
    assert category in {"breathing", "cardiac", "general", None}


def test_check_emergency_does_not_escalate_generic_caution() -> None:
    detected, category = check_emergency(
        user_question="I have mild headache after coffee.",
        ai_response="If symptoms persist, seek medical care soon.",
    )
    assert detected is False
    assert category is None


def test_requires_crisis_resources() -> None:
    assert requires_crisis_resources("I want to kill myself") is True
    assert requires_crisis_resources("I have a headache") is False


def test_assess_confidence_levels() -> None:
    high = assess_confidence(
        "According to guidelines this is well-established and most likely benign.",
        citations=[1, 2, 3],
    )
    low = assess_confidence(
        "I'm not sure and without more information this is uncertain.",
        citations=[],
    )

    assert high == "high"
    assert low == "low"


def test_extract_ai_safety_signal_positive() -> None:
    text, requires_emergency, category = extract_ai_safety_signal(
        'Advice text.\nSAFETY_SIGNAL: {"requiresEmergencyCare": true, "category": "cardiac"}'
    )
    assert text == "Advice text."
    assert requires_emergency is True
    assert category == "cardiac"


def test_extract_ai_safety_signal_negative() -> None:
    text, requires_emergency, category = extract_ai_safety_signal(
        'Advice text.\nSAFETY_SIGNAL: {"requiresEmergencyCare": false, "category": "none"}'
    )
    assert text == "Advice text."
    assert requires_emergency is False
    assert category is None


def test_extract_ai_safety_signal_invalid_gives_no_verdict() -> None:
    text, requires_emergency, category = extract_ai_safety_signal(
        "Advice text.\nSAFETY_SIGNAL: {invalid json}"
    )
    assert text == "Advice text."
    assert requires_emergency is None
    assert category is None


def test_extract_without_signal_gives_no_verdict() -> None:
    text, requires_emergency, category = extract_ai_safety_signal("Advice text.")
    assert text == "Advice text."
    assert requires_emergency is None
    assert category is None


def test_signal_not_on_last_line_is_parsed_and_removed() -> None:
    text, requires_emergency, category = extract_ai_safety_signal(
        'Advice.\nSAFETY_SIGNAL: {"requiresEmergencyCare": true, "category": "stroke"}\nMore.'
    )
    assert text == "Advice.\nMore."
    assert (requires_emergency, category) == (True, "stroke")


def _stream_through_filter(chunks: list[str]) -> str:
    signal_filter = SafetySignalFilter()
    shown = "".join(signal_filter.feed(chunk) for chunk in chunks)
    return shown + signal_filter.flush()


def test_filter_withholds_signal_line_split_across_chunks() -> None:
    shown = _stream_through_filter(
        ["Answer.\nSAFE", "TY_SIG", 'NAL: {"requiresEmergencyCare": false}']
    )
    assert shown == "Answer.\n"


def test_filter_releases_text_that_only_looks_like_signal_start() -> None:
    signal_filter = SafetySignalFilter()
    assert signal_filter.feed("Tips:\nSAFE travel") == "Tips:\nSAFE travel"
    assert signal_filter.flush() == ""


def test_signal_in_backticks_is_parsed_and_withheld() -> None:
    line = '`SAFETY_SIGNAL: {"requiresEmergencyCare": true, "category": "stroke"}`'
    assert _stream_through_filter(["Call now.\n", line]) == "Call now.\n"
    text, requires_emergency, category = extract_ai_safety_signal(f"Call now.\n{line}")
    assert text == "Call now."
    assert (requires_emergency, category) == (True, "stroke")


def test_missing_signal_falls_back_to_keyword_check() -> None:
    assert resolve_emergency("crushing chest pain now", None, None) == (True, "cardiac")


def test_ai_verdict_wins_over_keywords() -> None:
    assert resolve_emergency("I had chest pain last year, what now?", False, None) == (False, None)
