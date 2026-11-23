from __future__ import annotations

from dataclasses import dataclass
from typing import Any

_SNIPPET_MAX_CHARS = 300


@dataclass(frozen=True)
class Source:
    number: int
    title: str
    url: str
    source: str
    snippet: str


def _snippet(text: str) -> str:
    stripped = text.strip()
    if len(stripped) <= _SNIPPET_MAX_CHARS:
        return stripped
    return f"{stripped[: _SNIPPET_MAX_CHARS - 1].rstrip()}…"


class SourceRegistry:
    """Numbers every search result seen while answering one question.

    The model cites these numbers, and the server turns them back into real
    links, so citations never depend on how the model formats a source list.
    """

    def __init__(self) -> None:
        self._by_url: dict[str, Source] = {}
        self._by_number: dict[int, Source] = {}

    def register(self, results: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Number normalized search results and return the model-facing view."""
        model_facing: list[dict[str, Any]] = []
        for result in results:
            url = str(result.get("url") or "").strip()
            if not url:
                continue
            content = str(result.get("content") or "")
            source = self._by_url.get(url)
            if source is None:
                number = len(self._by_number) + 1
                source = Source(
                    number=number,
                    title=str(result.get("title") or "").strip() or url,
                    url=url,
                    source=str(result.get("source") or "").strip(),
                    snippet=_snippet(content),
                )
                self._by_url[url] = source
                self._by_number[number] = source
            model_facing.append(
                {
                    "n": source.number,
                    "title": source.title,
                    "source": source.source,
                    "url": url,
                    "content": content,
                }
            )
        return model_facing

    def get(self, number: int) -> Source | None:
        return self._by_number.get(number)

    def __len__(self) -> int:
        return len(self._by_number)
