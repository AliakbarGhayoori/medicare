from __future__ import annotations

import re
from dataclasses import asdict, dataclass

from src.ai.sources import SourceRegistry


@dataclass
class Citation:
    number: int
    source: str
    title: str
    url: str
    snippet: str = ""


def citations_as_dicts(citations: list[Citation]) -> list[dict]:
    return [asdict(citation) for citation in citations]


# --- Grounded citations -------------------------------------------------------
# Numbers in the answer refer to search results numbered by SourceRegistry. The
# model is told not to write a source list; if it writes one anyway (in any
# language or layout) it is stripped, and links always come from the registry.

_MARKER = r"(?:\[\^?\d{1,3}(?:[ \t]*[-\u2013,][ \t]*\d{1,3})*\]|\u3010\d{1,3}\u3011)"
_MARKER_GROUP_REGEX = re.compile(rf"([ \t]*)({_MARKER}(?:[ \t]*{_MARKER})*)")
_NUMBER_OR_RANGE_REGEX = re.compile(r"(\d{1,3})(?:[ \t]*[-\u2013][ \t]*(\d{1,3}))?")
_MAX_RANGE_SPAN = 10
# A source list the model writes anyway is stripped only when it is unmistakable:
# an explicit heading ("Sources:", "Kilder:", ...) over a block of list entries, or
# a trailing block in which every line starts with a citation marker. A prose or
# crisis line that merely contains a link is never removed, and an answer is never
# stripped to nothing.
_SOURCE_HEADINGS = frozenset(
    {
        "sources",
        "source",
        "references",
        "reference",
        "citations",
        "bibliography",
        "further reading",
        "sources and references",
        "references and sources",
        "kilder",
        "kilde",
        "kildehenvisninger",
        "referencer",
        "henvisninger",
        "kilder og referencer",
        "quellen",
        "quelle",
        "literatur",
        "fuentes",
        "referencias",
        "références",
        "bronnen",
        "referenties",
        "källor",
        "referenser",
        "fonti",
        "fontes",
    }
)
_URL_REGEX = re.compile(r"https?://", re.IGNORECASE)
_LIST_ITEM_REGEX = re.compile(r"^\s*(?:[-*\u2022]|\d{1,3}[.)])\s+")
_MARKER_LED_REGEX = re.compile(rf"^\s*(?:[-*\u2022]\s*)?{_MARKER}")


def _heading_key(line: str) -> str:
    core = re.sub(r"[#*_`]", "", line).strip().rstrip(":").strip()
    return re.sub(r"\s+", " ", core).casefold()


def _is_list_entry(line: str) -> bool:
    return bool(
        _URL_REGEX.search(line) or _LIST_ITEM_REGEX.match(line) or _MARKER_LED_REGEX.match(line)
    )


def _strip_trailing_source_list(text: str) -> str:
    lines = text.rstrip().split("\n")
    start = len(lines)
    while start > 0 and (not lines[start - 1].strip() or _is_list_entry(lines[start - 1])):
        start -= 1
    block = [line for line in lines[start:] if line.strip()]
    if not block:
        return text.rstrip()
    if start > 0 and _heading_key(lines[start - 1]) in _SOURCE_HEADINGS:
        start -= 1
    elif not all(_MARKER_LED_REGEX.match(line) for line in block):
        return text.rstrip()
    body = "\n".join(lines[:start]).rstrip()
    return body if body.strip() else text.rstrip()


def strip_citation_markers(text: str) -> str:
    """Remove [n] markers, and the spaces before them, e.g. from stored answers."""
    return _MARKER_GROUP_REGEX.sub("", text)


def _numbers_in(group: str) -> list[int]:
    numbers: list[int] = []
    for start_text, end_text in _NUMBER_OR_RANGE_REGEX.findall(group):
        start = int(start_text)
        if not end_text:
            numbers.append(start)
            continue
        end = int(end_text)
        if start <= end and end - start < _MAX_RANGE_SPAN:
            numbers.extend(range(start, end + 1))
        else:
            numbers.extend([start, end])
    return numbers


def finalize_citations(text: str, registry: SourceRegistry) -> tuple[str, list[Citation]]:
    """Resolve [n] markers against real search results and renumber them 1..k."""
    body = _strip_trailing_source_list(text)
    display_numbers: dict[int, int] = {}

    def _rewrite(match: re.Match[str]) -> str:
        leading, group = match.group(1), match.group(2)
        shown: list[int] = []
        for number in _numbers_in(group):
            if registry.get(number) is None:
                continue
            display = display_numbers.setdefault(number, len(display_numbers) + 1)
            if display not in shown:
                shown.append(display)
        if not shown:
            return ""
        return f"{leading}[{', '.join(str(n) for n in shown)}]"

    clean_text = _MARKER_GROUP_REGEX.sub(_rewrite, body).strip()

    citations: list[Citation] = []
    for number, display in sorted(display_numbers.items(), key=lambda item: item[1]):
        source = registry.get(number)
        if source is None:
            continue
        citations.append(
            Citation(
                number=display,
                source=source.source,
                title=source.title,
                url=source.url,
                snippet=source.snippet,
            )
        )
    return clean_text, citations
