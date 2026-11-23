from __future__ import annotations

import re

# Words that make up greetings, thanks, acknowledgements and farewells (English and
# Danish). A message made only of these words is small talk and gets no forced
# research round; anything else is treated as a health question.
_SMALL_TALK_WORDS = frozenset(
    {
        "hi",
        "hello",
        "hey",
        "good",
        "morning",
        "afternoon",
        "evening",
        "night",
        "thanks",
        "thank",
        "thx",
        "you",
        "so",
        "very",
        "much",
        "a",
        "lot",
        "again",
        "ok",
        "okay",
        "got",
        "it",
        "great",
        "perfect",
        "nice",
        "cool",
        "bye",
        "goodbye",
        "see",
        "later",
        "tak",
        "mange",
        "for",
        "det",
        "hej",
        "farvel",
        "godmorgen",
    }
)
_MAX_SMALL_TALK_WORDS = 6
_WORD_REGEX = re.compile(r"[^\W\d_]+")


def needs_research(question: str) -> bool:
    """True unless the message is pure small talk (greeting, thanks, farewell)."""
    words = [word.lower() for word in _WORD_REGEX.findall(question)]
    if len(words) > _MAX_SMALL_TALK_WORDS:
        return True
    return not all(word in _SMALL_TALK_WORDS for word in words)
