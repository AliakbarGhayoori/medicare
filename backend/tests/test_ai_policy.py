from __future__ import annotations

import pytest

from src.ai.policy import needs_research


@pytest.mark.parametrize(
    ("question", "expected"),
    [
        ("thanks!", False),
        ("Thank you so much 🙏", False),
        ("ok, thanks", False),
        ("Got it.", False),
        ("Tak", False),
        ("hej", False),
        ("Good morning", False),
        ("chest pain", True),
        ("I have been dizzy for 2 weeks", True),
        ("ok so my knee hurts", True),
        ("Can I take ibuprofen?", True),
        ("Thanks. Is it safe with metformin?", True),
    ],
)
def test_needs_research(question: str, expected: bool) -> None:
    assert needs_research(question) is expected
