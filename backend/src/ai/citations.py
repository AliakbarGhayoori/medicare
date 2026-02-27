from __future__ import annotations

import re
import urllib.parse
from dataclasses import asdict, dataclass


@dataclass
class Citation:
    number: int
    source: str
    title: str
    url: str
    snippet: str = ""


_SOURCES_BLOCK_REGEX = re.compile(
    r"\n(?:Sources|References):\s*\n((?:\[\d+\].+\n?)+)",
    re.IGNORECASE,
)
_CITATION_LINE_REGEX = re.compile(
    r'^\[(\d+)\]\s*(.+?)(?:\s*[-–]\s*["“](.+?)["”])?\s*(?:\((https?://\S+)\))?\s*$'
)


def extract_citations_from_response(response_text: str) -> tuple[str, list[Citation]]:
    match = _SOURCES_BLOCK_REGEX.search(response_text)
    if not match:
        return response_text.strip(), []

    sources_block = match.group(1)
    clean_text = response_text[: match.start()].rstrip()

    citations: list[Citation] = []
    for line in sources_block.strip().splitlines():
        parsed = _CITATION_LINE_REGEX.match(line.strip())
        if not parsed:
            continue
        number = int(parsed.group(1))
        source = (parsed.group(2) or "").strip()
        title = (parsed.group(3) or source).strip()
        url = (parsed.group(4) or "").strip()
        citations.append(Citation(number=number, source=source, title=title, url=url, snippet=""))

    return clean_text, citations


def validate_citations(clean_text: str, citations: list[Citation]) -> list[Citation]:
    valid: list[Citation] = []
    seen: set[int] = set()

    for citation in citations:
        if citation.number in seen:
            continue
        if f"[{citation.number}]" not in clean_text:
            continue

        if citation.url:
            parsed = urllib.parse.urlparse(citation.url)
            if parsed.scheme not in ("http", "https") or not parsed.netloc:
                citation.url = ""

        valid.append(citation)
        seen.add(citation.number)

    return valid


def citations_as_dicts(citations: list[Citation]) -> list[dict]:
    return [asdict(citation) for citation in citations]
