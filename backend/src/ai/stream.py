from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from typing import Any

import openai

from src.ai.client import chat_model_options, get_openai_client
from src.ai.policy import needs_research
from src.ai.prompts import build_messages, build_system_prompt
from src.ai.sources import SourceRegistry
from src.ai.tavily import execute_tavily_search
from src.config import get_settings
from src.exceptions import APIError

logger = logging.getLogger(__name__)

_TAVILY_TOOL_NAME = "tavily_search"
_TAVILY_SEARCH_TOOL: dict[str, Any] = {
    "type": "function",
    "function": {
        "name": _TAVILY_TOOL_NAME,
        "description": (
            "Search trusted medical sources. Call it several times in parallel with "
            "different specific queries (causes, red flags, treatment, medication "
            "safety). Every result has a number n: cite it in your answer as [n]."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": (
                        "Specific long-tail query. Include the population, symptom "
                        "context and intent."
                    ),
                },
                "search_depth": {
                    "type": "string",
                    "enum": ["basic", "advanced"],
                    "description": "Use advanced unless speed is critical.",
                },
            },
            "required": ["query"],
        },
    },
}

_CREATE_RETRY_ATTEMPTS = 2
_FATAL_SEARCH_ERRORS = {"SEARCH_BACKEND_UNAVAILABLE", "SEARCH_BACKEND_AUTH_ERROR"}
_TEXT_FIELDS = ("text", "summary", "data")

_MOCK_SOURCE = {
    "title": "Dizziness - Symptoms and causes",
    "url": "https://www.mayoclinic.org/symptoms/dizziness/basics/causes/sym-20050886",
    "source": "mayoclinic.org",
    "content": "Dizziness has many possible causes, including inner ear problems, "
    "dehydration, medication side effects and changes in blood pressure.",
}


@dataclass
class RoundResult:
    content: str = ""
    tool_calls: list[dict[str, Any]] = field(default_factory=list)
    reasoning_details: list[dict[str, Any]] = field(default_factory=list)
    finish_reason: str | None = None
    model: str | None = None  # the model that actually served the round (fallback-aware)


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
            "⚠️ IMPORTANT: Based on what you're describing, this could be a medical "
            "emergency. Call your local emergency number now (911 in the US, 112 in "
            "Europe) or go to the nearest emergency room.\n\n"
            f"{context_hint}\n\n"
            "**What to do next**\n"
            "- Call emergency services now.\n"
            "- Do not drive yourself.\n"
            "- Keep emergency contacts informed.\n"
            'SAFETY_SIGNAL: {"requiresEmergencyCare": true, "category": "cardiac"}\n'
        )

    return (
        f"{context_hint}\n\n"
        "Possible causes include medication side effects, dehydration, "
        "or blood pressure changes [1].\n\n"
        "**What to do next**\n"
        "- Monitor symptoms and hydration today.\n"
        "- If symptoms persist, see your doctor within 24 hours.\n"
        "- If symptoms suddenly worsen, seek urgent care.\n"
        'SAFETY_SIGNAL: {"requiresEmergencyCare": false, "category": "none"}\n'
    )


def _extract_status_code(exc: Exception) -> int | None:
    status = getattr(exc, "status_code", None)
    if isinstance(status, int):
        return status
    response = getattr(exc, "response", None)
    status = getattr(response, "status_code", None)
    return status if isinstance(status, int) else None


def _extract_retry_after(exc: Exception) -> int | None:
    headers = getattr(getattr(exc, "response", None), "headers", None)
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


def _rate_limited_error(exc: Exception) -> APIError:
    retry_after = _extract_retry_after(exc)
    headers = {"Retry-After": str(retry_after)} if retry_after else {}
    return APIError(
        429, "RATE_LIMITED", "AI rate limit exceeded. Try again shortly.", headers=headers
    )


def _parse_positive_int(value: object, fallback: int, *, allow_zero: bool = False) -> int:
    if isinstance(value, int) and (value > 0 or (allow_zero and value == 0)):
        return value
    return fallback


def _can_use_live_ai(settings: Any) -> bool:
    if settings.mock_ai:
        return False
    return bool(settings.openrouter_api_key or settings.anthropic_api_key)


async def _create_chat_with_retry(*, client: Any, request_kwargs: dict[str, Any]) -> Any:
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
        except APIError:
            raise
        except Exception as exc:
            last_exception = exc
            retryable = _extract_status_code(exc) in {500, 502, 503, 504}
            if retryable and attempt < _CREATE_RETRY_ATTEMPTS:
                await asyncio.sleep(2)
                continue
            break
    raise APIError(
        502, "AI_ERROR", "Unable to generate response from AI model."
    ) from last_exception


def _merge_tool_call_delta(calls: dict[int, dict[str, Any]], delta: Any) -> None:
    index = getattr(delta, "index", None) or 0
    entry = calls.setdefault(
        index, {"id": None, "type": "function", "function": {"name": "", "arguments": ""}}
    )
    if getattr(delta, "id", None):
        entry["id"] = delta.id
    function = getattr(delta, "function", None)
    if function is None:
        return
    name = getattr(function, "name", None)
    # Some providers repeat the full name in every delta; others send it once.
    if name and not entry["function"]["name"].endswith(name):
        entry["function"]["name"] += name
    arguments = getattr(function, "arguments", None)
    if arguments:
        entry["function"]["arguments"] += arguments


def _merge_reasoning_items(merged: list[dict[str, Any]], items: list[Any]) -> None:
    """Accumulate streamed reasoning_details (Gemini thought signatures etc.).

    They must be sent back with the tool calls; without them the model forgets
    that it already searched and searches again.
    """
    for raw in items:
        item = dict(raw) if isinstance(raw, dict) else dict(raw.model_dump())
        last = merged[-1] if merged else None
        if (
            last is None
            or item.get("index") is None
            or last.get("index") != item.get("index")
            or last.get("type") != item.get("type")
        ):
            merged.append(item)
            continue
        for key, value in item.items():
            if key in _TEXT_FIELDS and isinstance(value, str):
                last[key] = (last.get(key) or "") + value
            elif value is not None and last.get(key) is None:
                last[key] = value


async def _stream_round(
    client: Any, request_kwargs: dict[str, Any], round_idx: int
) -> AsyncIterator[str | RoundResult]:
    """Yield the round's text deltas as they arrive, then its RoundResult."""
    stream = await _create_chat_with_retry(client=client, request_kwargs=request_kwargs)
    result = RoundResult()
    calls: dict[int, dict[str, Any]] = {}
    try:
        async for chunk in stream:
            if result.model is None:
                result.model = getattr(chunk, "model", None) or None
            choices = getattr(chunk, "choices", None) or []
            if not choices:
                continue
            choice = choices[0]
            if getattr(choice, "finish_reason", None):
                result.finish_reason = choice.finish_reason
            delta = getattr(choice, "delta", None)
            if delta is None:
                continue
            text = getattr(delta, "content", None)
            if text:
                result.content += text
                yield text
            for tool_delta in getattr(delta, "tool_calls", None) or []:
                _merge_tool_call_delta(calls, tool_delta)
            extra = getattr(delta, "model_extra", None) or {}
            details = extra.get("reasoning_details") if isinstance(extra, dict) else None
            if details:
                _merge_reasoning_items(result.reasoning_details, details)
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "AI_ERROR", "The AI response was interrupted.") from exc

    for index in sorted(calls):
        call = calls[index]
        call["id"] = call["id"] or f"call_{round_idx}_{index}"
        result.tool_calls.append(call)
    yield result


def _parse_arguments(tool_call: dict[str, Any]) -> dict[str, Any]:
    try:
        parsed = json.loads(tool_call["function"]["arguments"] or "{}")
    except (json.JSONDecodeError, KeyError, TypeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _query_of(tool_call: dict[str, Any]) -> str:
    return str(_parse_arguments(tool_call).get("query") or "").strip()


def _tool_message(tool_call_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    return {"role": "tool", "tool_call_id": tool_call_id, "content": json.dumps(payload)}


async def _execute_tool_call(tool_call: dict[str, Any], sources: SourceRegistry) -> dict[str, Any]:
    call_id = tool_call["id"]
    name = tool_call["function"]["name"]
    if name != _TAVILY_TOOL_NAME:
        error = {"code": "UNKNOWN_TOOL", "message": f"Unsupported tool '{name}'."}
        return _tool_message(call_id, {"ok": False, "error": error})

    arguments = _parse_arguments(tool_call)
    query = str(arguments.get("query") or "").strip()
    if not query:
        error = {"code": "VALIDATION_ERROR", "message": "Search query cannot be empty."}
        return _tool_message(call_id, {"ok": False, "error": error})

    depth = arguments.get("search_depth")
    try:
        payload = await execute_tavily_search(
            query=query, search_depth=depth if isinstance(depth, str) else None
        )
    except APIError as exc:
        if exc.code in _FATAL_SEARCH_ERRORS:
            raise
        error = {"code": exc.code, "message": exc.message}
        return _tool_message(call_id, {"ok": False, "query": query, "error": error})

    results = sources.register(list(payload.get("results") or []))
    return _tool_message(call_id, {"ok": True, "query": query, "results": results})


def _budget_exhausted_message(tool_call: dict[str, Any]) -> dict[str, Any]:
    error = {
        "code": "SEARCH_BUDGET_EXHAUSTED",
        "message": "Search limit reached. Answer with the results you already have.",
    }
    return _tool_message(tool_call["id"], {"ok": False, "error": error})


async def _mock_events(
    question: str, v10_digest: str | None, sources: SourceRegistry, chunk_size: int
) -> AsyncIterator[dict]:
    yield {"type": "tool_use", "tool": _TAVILY_TOOL_NAME, "status": "searching", "query": None}
    sources.register([_MOCK_SOURCE])
    for chunk in _chunk_text(_mock_response(question, v10_digest), chunk_size):
        yield {"type": "token", "text": chunk}


async def generate_response_events(
    question: str,
    conversation_history: list[dict],
    v10_digest: str | None,
    sources: SourceRegistry,
    answer_format: str | None = None,
) -> AsyncIterator[dict]:
    """Stream one answer: research rounds first, then the answer token by token.

    Yields ``tool_use`` events while searching and ``token`` events with the raw
    model text (including the trailing SAFETY_SIGNAL line). Every search result
    is numbered in ``sources``; the answer cites those numbers.
    """
    settings = get_settings()

    if not _can_use_live_ai(settings):
        async for event in _mock_events(question, v10_digest, sources, settings.sse_chunk_size):
            yield event
        return

    messages: list[dict[str, Any]] = [
        {"role": "system", "content": build_system_prompt(v10_digest, answer_format)},
        *build_messages(
            conversation_history=conversation_history,
            user_question=question,
            max_history_messages=settings.max_conversation_context_messages,
        ),
    ]
    client = get_openai_client()

    max_rounds = _parse_positive_int(getattr(settings, "ai_tool_max_rounds", None), fallback=6)
    max_searches = _parse_positive_int(getattr(settings, "ai_tool_max_calls", None), fallback=12)
    min_searches = _parse_positive_int(
        getattr(settings, "ai_tool_min_calls", None), fallback=2, allow_zero=True
    )
    research_required = needs_research(question)
    searches = 0
    produced_text = False
    last_char = ""  # last character already streamed, across rounds

    yield {"type": "tool_use", "tool": _TAVILY_TOOL_NAME, "status": "planning", "query": None}

    for round_idx in range(max_rounds):
        request: dict[str, Any] = {
            **chat_model_options(settings),
            "max_tokens": settings.ai_max_tokens,
            "temperature": settings.ai_temperature,
            "messages": messages,
            "stream": True,
        }
        # Withholding the tool is the only reliable way to force a final answer:
        # gemini-4-neon ignores tool_choice="none".
        final_round = round_idx == max_rounds - 1 or searches >= max_searches
        if not final_round:
            request["tools"] = [_TAVILY_SEARCH_TOOL]
            request["tool_choice"] = (
                "required" if research_required and searches < min_searches else "auto"
            )
            request["parallel_tool_calls"] = True

        started = time.monotonic()
        result = RoundResult()
        round_has_text = False
        async for item in _stream_round(client, request, round_idx):
            if isinstance(item, RoundResult):
                result = item
                continue
            if not round_has_text and last_char and not last_char.isspace():
                # A preamble from an earlier round must not run into this round's text.
                yield {"type": "token", "text": "\n\n"}
            round_has_text = True
            produced_text = True
            last_char = item[-1]
            yield {"type": "token", "text": item}
        round_ms = int((time.monotonic() - started) * 1000)

        if not result.tool_calls or final_round:
            logger.info(
                "ai_round round=%d ms=%d action=final_text chars=%d finish=%s model=%s",
                round_idx,
                round_ms,
                len(result.content),
                result.finish_reason,
                result.model or "unknown",
            )
            if not produced_text:
                raise APIError(502, "AI_ERROR", "AI response contained no text output.")
            return

        logger.info(
            "ai_round round=%d ms=%d action=tool_calls count=%d model=%s",
            round_idx,
            round_ms,
            len(result.tool_calls),
            result.model or "unknown",
        )
        assistant_message: dict[str, Any] = {
            "role": "assistant",
            "content": result.content or None,
            "tool_calls": result.tool_calls,
        }
        if result.reasoning_details:
            assistant_message["reasoning_details"] = result.reasoning_details
        messages.append(assistant_message)

        runnable = result.tool_calls[: max(0, max_searches - searches)]
        skipped = result.tool_calls[len(runnable) :]
        for tool_call in runnable:
            yield {
                "type": "tool_use",
                "tool": _TAVILY_TOOL_NAME,
                "status": "searching",
                "query": _query_of(tool_call),
            }
        searches += len(runnable)

        started = time.monotonic()
        tool_messages = await asyncio.gather(
            *[_execute_tool_call(tool_call, sources) for tool_call in runnable]
        )
        logger.info(
            "search_round round=%d ms=%d searches=%d skipped=%d sources=%d",
            round_idx,
            int((time.monotonic() - started) * 1000),
            len(runnable),
            len(skipped),
            len(sources),
        )
        messages.extend(tool_messages)
        messages.extend(_budget_exhausted_message(tool_call) for tool_call in skipped)

    raise APIError(502, "AI_ERROR", "AI did not complete tool use within limits.")
