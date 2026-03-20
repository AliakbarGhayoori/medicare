from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator
from typing import Any

import openai

from src.ai.client import get_openai_client
from src.ai.prompts import build_messages, build_system_prompt
from src.ai.tavily import execute_tavily_search
from src.config import get_settings
from src.exceptions import APIError

logger = logging.getLogger(__name__)

_TAVILY_TOOL_NAME = "tavily_search"
_TAVILY_SEARCH_TOOL_OPENAI = {
    "type": "function",
    "function": {
        "name": _TAVILY_TOOL_NAME,
        "description": (
            "Search trusted medical web sources. You MUST provide multiple "
            "queries in the 'queries' array to cover different aspects of the "
            "question in a single call. All queries run in parallel for speed. "
            "Cover differential diagnosis, red flags, treatment, and medication "
            "safety when relevant. Always use 3-5 queries per call."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "queries": {
                    "type": "array",
                    "items": {"type": "string"},
                    "minItems": 1,
                    "maxItems": 6,
                    "description": (
                        "Array of 3-5 specific long-tail queries for medical evidence. "
                        "Each query should cover a different aspect: causes, treatment, "
                        "red flags, medication interactions, etc."
                    ),
                },
                "search_depth": {
                    "type": "string",
                    "enum": ["basic", "advanced"],
                    "description": "Use advanced unless speed is critical.",
                },
            },
            "required": ["queries"],
        },
    },
}

_CREATE_RETRY_ATTEMPTS = 2


def _chunk_text(text: str, chunk_size: int) -> list[str]:
    if not text:
        return []
    return [text[i : i + chunk_size] for i in range(0, len(text), chunk_size)]


def _mock_response(question: str, v10_digest: str | None) -> str:
    context_hint = (
        "Given your existing health profile, this may relate to your current conditions [1]."
        if v10_digest
        else "Based on common clinical guidance, this could have multiple causes [1]."
    )

    question_lower = question.lower()
    if "chest pain" in question_lower or "can't breathe" in question_lower:
        return (
            "⚠️ IMPORTANT: Based on what you're describing, this could be "
            "a medical emergency. Please call 911 now or go to the nearest "
            "emergency room immediately.\n\n"
            f"{context_hint}\n\n"
            "**What to do next**\n"
            "- Call 911 now.\n"
            "- Do not drive yourself.\n"
            "- Keep emergency contacts informed.\n\n"
            "Sources:\n"
            '[1] Mayo Clinic - "Heart attack" '
            "(https://www.mayoclinic.org/diseases-conditions/heart-attack/)\n"
            'SAFETY_SIGNAL: {"requiresEmergencyCare": true, '
            '"category": "cardiac"}\n'
        )

    return (
        f"{context_hint}\n\n"
        "Possible causes include medication side effects, dehydration, "
        "or blood pressure changes [1].\n\n"
        "**What to do next**\n"
        "- Monitor symptoms and hydration today.\n"
        "- If symptoms persist, see your doctor within 24 hours.\n"
        "- If symptoms suddenly worsen, seek urgent care.\n\n"
        "Sources:\n"
        '[1] Mayo Clinic - "Dizziness" '
        "(https://www.mayoclinic.org/symptoms/dizziness/)\n"
        'SAFETY_SIGNAL: {"requiresEmergencyCare": false, '
        '"category": "none"}\n'
    )


def _extract_status_code(exc: Exception) -> int | None:
    try:
        status = exc.status_code  # type: ignore[attr-defined]
        if isinstance(status, int):
            return status
    except AttributeError:
        pass

    response = getattr(exc, "response", None)
    status = getattr(response, "status_code", None)
    if isinstance(status, int):
        return status
    return None


def _extract_retry_after(exc: Exception) -> int | None:
    response = getattr(exc, "response", None)
    headers = getattr(response, "headers", None)
    if not headers:
        return None

    raw = headers.get("retry-after") or headers.get("Retry-After")
    if not raw:
        return None

    try:
        retry_after = int(float(raw))
    except (TypeError, ValueError):
        return None
    return retry_after if retry_after > 0 else None


def _is_retryable_server_error(exc: Exception) -> bool:
    status_code = _extract_status_code(exc)
    return status_code in {500, 502, 503, 504}


def _rate_limited_error(exc: Exception) -> APIError:
    retry_after = _extract_retry_after(exc)
    headers = {"Retry-After": str(retry_after)} if retry_after else {}
    return APIError(
        429,
        "RATE_LIMITED",
        "AI rate limit exceeded. Try again shortly.",
        headers=headers,
    )


def _parse_positive_int(value: object, fallback: int, *, allow_zero: bool = False) -> int:
    if isinstance(value, int):
        if allow_zero and value >= 0:
            return value
        if value > 0:
            return value
    return fallback


def _can_use_live_ai(settings: Any) -> bool:
    if settings.mock_ai:
        return False
    return bool(settings.openrouter_api_key or settings.anthropic_api_key)


async def _create_chat_with_retry(*, client: Any, request_kwargs: dict[str, Any]) -> object:
    last_exception: Exception | None = None
    for attempt in range(1, _CREATE_RETRY_ATTEMPTS + 1):
        try:
            return await client.chat.completions.create(**request_kwargs)
        except openai.RateLimitError as exc:
            raise _rate_limited_error(exc) from exc
        except openai.APITimeoutError as exc:
            last_exception = exc
            if attempt < _CREATE_RETRY_ATTEMPTS:
                await asyncio.sleep(0.4)
                continue
            raise APIError(504, "AI_TIMEOUT", "AI response timed out.") from exc
        except Exception as exc:
            if isinstance(exc, APIError):
                raise
            last_exception = exc
            if _is_retryable_server_error(exc) and attempt < _CREATE_RETRY_ATTEMPTS:
                await asyncio.sleep(2)
                continue
            break

    raise APIError(
        502,
        "AI_ERROR",
        "Unable to generate response from AI model.",
    ) from last_exception


def _tool_call_query_preview(tool_call: Any) -> str:
    """Extract a preview of search queries from an OpenAI-format tool call."""
    try:
        args = tool_call.function.arguments
        if isinstance(args, str):
            parsed = json.loads(args)
            # New format: queries array
            queries = parsed.get("queries")
            if isinstance(queries, list) and queries:
                return str(queries[0]).strip()
            # Legacy format: single query
            return str(parsed.get("query", "")).strip()
    except (json.JSONDecodeError, AttributeError):
        pass
    return ""


def _parse_tool_call_args(tool_call: Any) -> dict[str, Any]:
    """Parse tool call arguments from OpenAI format."""
    try:
        args = tool_call.function.arguments
        if isinstance(args, str):
            return json.loads(args)
    except (json.JSONDecodeError, AttributeError):
        pass
    return {}


async def _execute_single_search(
    query: str,
    search_depth: str | None = None,
) -> dict[str, Any]:
    """Execute a single Tavily search and return the result dict."""
    try:
        search_payload = await execute_tavily_search(
            query=query,
            search_depth=search_depth,
        )
        return {"ok": True, "query": query, "search": search_payload}
    except APIError as exc:
        if exc.code in {
            "SEARCH_BACKEND_UNAVAILABLE",
            "SEARCH_BACKEND_AUTH_ERROR",
        }:
            raise
        return {
            "ok": False,
            "query": query,
            "error": {"code": exc.code, "message": exc.message},
        }


async def _execute_tool_call_openai(
    tool_call: Any,
) -> tuple[dict[str, str], list[str]]:
    """Execute a tool call and return (OpenAI-format tool result, list of queries)."""
    tool_call_id = tool_call.id
    tool_name = tool_call.function.name
    tool_input = _parse_tool_call_args(tool_call)

    if tool_name != _TAVILY_TOOL_NAME:
        error_payload = {
            "ok": False,
            "error": {
                "code": "UNKNOWN_TOOL",
                "message": f"Unsupported tool '{tool_name}'.",
            },
        }
        return {
            "role": "tool",
            "tool_call_id": tool_call_id,
            "content": json.dumps(error_payload),
        }, []

    # Support both "queries" (array) and legacy "query" (string)
    queries: list[str] = []
    raw_queries = tool_input.get("queries")
    if isinstance(raw_queries, list):
        queries = [str(q).strip() for q in raw_queries if str(q).strip()]
    if not queries:
        # Fallback to single "query" field
        single = str(tool_input.get("query") or "").strip()
        if single:
            queries = [single]

    if not queries:
        error_payload = {
            "ok": False,
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "At least one search query is required.",
            },
        }
        return {
            "role": "tool",
            "tool_call_id": tool_call_id,
            "content": json.dumps(error_payload),
        }, []

    search_depth = (
        str(tool_input.get("search_depth"))
        if isinstance(tool_input.get("search_depth"), str)
        else None
    )

    # Execute ALL queries in parallel
    results = await asyncio.gather(
        *[_execute_single_search(q, search_depth) for q in queries]
    )

    payload = {
        "ok": True,
        "queries": queries,
        "results": list(results),
    }
    return {
        "role": "tool",
        "tool_call_id": tool_call_id,
        "content": json.dumps(payload),
    }, queries


async def generate_response_events(
    question: str,
    conversation_history: list[dict],
    v10_digest: str | None,
) -> AsyncIterator[dict]:
    settings = get_settings()

    if not _can_use_live_ai(settings):
        yield {
            "type": "tool_use",
            "tool": _TAVILY_TOOL_NAME,
            "status": "searching",
        }
        mock_text = _mock_response(question, v10_digest)
        for chunk in _chunk_text(mock_text, settings.sse_chunk_size):
            yield {"type": "token", "text": chunk}
        return

    system_prompt = build_system_prompt(v10_digest)
    messages: list[dict] = [
        {"role": "system", "content": system_prompt},
    ]
    # Add conversation history
    for msg in build_messages(
        conversation_history=conversation_history,
        user_question=question,
        max_history_messages=settings.max_conversation_context_messages,
    ):
        messages.append(msg)

    client = get_openai_client()

    max_rounds = _parse_positive_int(getattr(settings, "ai_tool_max_rounds", None), fallback=6)
    max_tool_calls = _parse_positive_int(getattr(settings, "ai_tool_max_calls", None), fallback=12)
    total_tool_calls = 0

    yield {
        "type": "tool_use",
        "tool": _TAVILY_TOOL_NAME,
        "status": "planning",
        "query": None,
    }

    import time as _time

    for _round_idx in range(max_rounds):
        t0 = _time.monotonic()
        response = await _create_chat_with_retry(
            client=client,
            request_kwargs={
                "model": settings.anthropic_model,
                "max_tokens": settings.anthropic_max_tokens,
                "temperature": settings.ai_temperature,
                "messages": messages,
                "tools": [_TAVILY_SEARCH_TOOL_OPENAI],
                "tool_choice": "auto",
            },
        )
        ai_ms = int((_time.monotonic() - t0) * 1000)

        choice = response.choices[0]
        assistant_message = choice.message

        # No tool calls — model is done, emit text
        if not assistant_message.tool_calls:
            final_text = (assistant_message.content or "").strip()
            logger.info("ai_round round=%d ai_ms=%d action=final_text len=%d",
                        _round_idx, ai_ms, len(final_text))
            if not final_text:
                raise APIError(502, "AI_ERROR", "AI response contained no text output.")
            for chunk in _chunk_text(final_text, settings.sse_chunk_size):
                yield {"type": "token", "text": chunk}
            return

        # Model wants to call tools
        tool_calls = assistant_message.tool_calls
        logger.info("ai_round round=%d ai_ms=%d action=tool_calls count=%d queries=%s",
                    _round_idx, ai_ms, len(tool_calls),
                    [_tool_call_query_preview(tc) for tc in tool_calls])
        if total_tool_calls + len(tool_calls) > max_tool_calls:
            raise APIError(502, "AI_ERROR", "AI used too many search tool calls.")

        # Add assistant message with tool_calls to conversation
        messages.append(assistant_message.model_dump())

        # Execute tool calls (each may contain multiple queries run in parallel)
        for tc in tool_calls:
            total_tool_calls += 1
            t1 = _time.monotonic()
            tool_result, queries_used = await _execute_tool_call_openai(tc)
            search_ms = int((_time.monotonic() - t1) * 1000)
            logger.info("tavily_batch round=%d search_ms=%d query_count=%d queries=%s",
                        _round_idx, search_ms, len(queries_used), queries_used)

            # Emit SSE for each query so the UI widget shows what's being searched
            for q in queries_used:
                yield {
                    "type": "tool_use",
                    "tool": _TAVILY_TOOL_NAME,
                    "status": "searching",
                    "query": q,
                }

            messages.append(tool_result)

    raise APIError(502, "AI_ERROR", "AI did not complete tool use within limits.")
