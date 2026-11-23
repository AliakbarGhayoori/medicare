from __future__ import annotations

from src.ai.prompts import build_messages, build_system_prompt
from src.ai.safety import extract_ai_safety_signal

_CATEGORIES = (
    "<cardiac|stroke|breathing|severe_bleeding|consciousness|self_harm|poisoning|"
    "severe_pain|general|none>"
)
_SIGNAL_FORMAT = (
    'SAFETY_SIGNAL: {"requiresEmergencyCare": <true|false>, "category": "' + _CATEGORIES + '"}'
)


def test_prompt_asks_for_registry_numbers_and_no_source_list() -> None:
    prompt = build_system_prompt(None)

    assert "[n]" in prompt
    assert '"Sources:" section' not in prompt
    assert "skip the search" not in prompt


def test_prompt_names_local_emergency_numbers_not_only_911() -> None:
    prompt = build_system_prompt(None)

    assert "112" in prompt
    assert "your local emergency number (for example 112 in Europe or 911 in the US)" in prompt
    assert "findahelpline.com" in prompt
    assert "tell them to call 911" not in prompt


def test_prompt_replies_in_the_users_language() -> None:
    assert "language the user writes in" in build_system_prompt(None)


def test_prompt_signal_format_is_unchanged_and_parseable() -> None:
    prompt = build_system_prompt("Takes metformin.")

    assert _SIGNAL_FORMAT in prompt
    assert "Takes metformin." in prompt
    example = _SIGNAL_FORMAT.replace("<true|false>", "true").replace(_CATEGORIES, "stroke")
    parsed = extract_ai_safety_signal(f"Call 112 now.\n{example}")
    assert parsed == ("Call 112 now.", True, "stroke")


def test_history_answers_lose_old_citation_numbers() -> None:
    history = [
        {"role": "user", "content": "Is [1] a thing?"},
        {"role": "assistant", "content": "Rest helps [1]. Fluids too [2, 3]."},
    ]

    messages = build_messages(history, "And for kids?", max_history_messages=10)

    assert messages == [
        {"role": "user", "content": "Is [1] a thing?"},
        {"role": "assistant", "content": "Rest helps. Fluids too."},
        {"role": "user", "content": "And for kids?"},
    ]


def test_default_prompt_has_no_answer_layout_rules() -> None:
    prompt = build_system_prompt("Takes metformin.")

    assert prompt == build_system_prompt("Takes metformin.", answer_format=None)
    assert "Do this:" not in prompt
    assert "Watch for:" not in prompt


def test_sections_prompt_keeps_the_default_prompt_and_adds_the_layout() -> None:
    default = build_system_prompt("Takes metformin.")
    prompt = build_system_prompt("Takes metformin.", answer_format="sections")

    assert prompt.startswith(default)
    assert "Do this:" in prompt
    assert "Watch for:" in prompt
    assert "one plain sentence" in prompt
    assert "small talk" in prompt
    assert _SIGNAL_FORMAT in prompt
