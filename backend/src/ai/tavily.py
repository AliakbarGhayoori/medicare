from __future__ import annotations

import logging
from typing import Any
from urllib.parse import urlparse

import httpx

from src.config import get_settings
from src.exceptions import APIError

logger = logging.getLogger(__name__)

_MAX_SNIPPET_CHARS = 1200
_MAX_ANSWER_CHARS = 2000


def _truncate(text: str, max_chars: int) -> str:
    stripped = text.strip()
    if len(stripped) <= max_chars:
        return stripped
    return f"{stripped[: max_chars - 1].rstrip()}…"


def _source_from_url(url: str) -> str:
    parsed = urlparse(url)
    host = (parsed.netloc or "").lower()
    if host.startswith("www."):
        host = host[4:]
    return host or "unknown"


def _normalize_result(item: object) -> dict[str, Any] | None:
    if not isinstance(item, dict):
        return None

    url = str(item.get("url") or "").strip()
    title = str(item.get("title") or "").strip()
    content = str(item.get("content") or "").strip()
    favicon = str(item.get("favicon") or "").strip()
    score = item.get("score")

    if not url:
        return None

    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return None

    return {
        "title": title or _source_from_url(url),
        "url": url,
        "source": _source_from_url(url),
        "content": _truncate(content, _MAX_SNIPPET_CHARS),
        "favicon": favicon if favicon.startswith(("http://", "https://")) else "",
        "score": float(score) if isinstance(score, (int, float)) else None,
    }


def _normalize_response(data: object, fallback_query: str) -> dict[str, Any]:
    if not isinstance(data, dict):
        return {
            "query": fallback_query,
            "answer": "",
            "results": [],
            "request_id": "",
            "response_time": None,
        }

    raw_results = data.get("results")
    normalized_results: list[dict[str, Any]] = []
    if isinstance(raw_results, list):
        for item in raw_results:
            normalized = _normalize_result(item)
            if normalized:
                normalized_results.append(normalized)

    answer = data.get("answer")
    return {
        "query": str(data.get("query") or fallback_query).strip(),
        "answer": _truncate(str(answer), _MAX_ANSWER_CHARS) if isinstance(answer, str) else "",
        "results": normalized_results,
        "request_id": str(data.get("request_id") or ""),
        "response_time": data.get("response_time"),
    }


async def execute_tavily_search(
    query: str,
    *,
    search_depth: str | None = None,
    include_answer: str | None = None,
    include_favicon: bool | None = None,
    max_results: int | None = None,
) -> dict[str, Any]:
    settings = get_settings()
    if not settings.tavily_api_key:
        raise APIError(
            500,
            "SEARCH_BACKEND_UNAVAILABLE",
            "Tavily API key is missing. Configure TAVILY_API_KEY.",
        )

    normalized_query = query.strip()
    if not normalized_query:
        raise APIError(422, "VALIDATION_ERROR", "Search query cannot be empty.")

    request_payload = {
        "api_key": settings.tavily_api_key,
        "query": normalized_query,
        "search_depth": search_depth or settings.tavily_search_depth,
        "include_answer": include_answer or settings.tavily_include_answer,
        "include_favicon": (
            settings.tavily_include_favicon if include_favicon is None else include_favicon
        ),
        "max_results": max_results or settings.tavily_max_results,
    }

    endpoint = f"{settings.tavily_base_url.rstrip('/')}/search"
    timeout = httpx.Timeout(settings.tavily_timeout_seconds)

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(endpoint, json=request_payload)
            response.raise_for_status()
    except httpx.TimeoutException as exc:
        raise APIError(504, "SEARCH_TIMEOUT", "Tavily search timed out.") from exc
    except httpx.HTTPStatusError as exc:
        status_code = exc.response.status_code
        if status_code in {401, 403}:
            raise APIError(
                502,
                "SEARCH_BACKEND_AUTH_ERROR",
                "Tavily rejected the API key.",
            ) from exc

        logger.warning(
            "Tavily returned HTTP error",
            extra={"status_code": status_code, "query": normalized_query[:120]},
        )
        raise APIError(
            502,
            "SEARCH_BACKEND_ERROR",
            "Tavily search failed.",
        ) from exc
    except httpx.HTTPError as exc:
        raise APIError(502, "SEARCH_BACKEND_ERROR", "Unable to reach Tavily search.") from exc

    try:
        payload = response.json()
    except ValueError as exc:
        raise APIError(
            502,
            "SEARCH_BACKEND_ERROR",
            "Tavily returned an invalid JSON payload.",
        ) from exc

    return _normalize_response(payload, fallback_query=normalized_query)
