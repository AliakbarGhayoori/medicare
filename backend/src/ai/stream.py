from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator
from typing import Any, cast

import anthropic

from src.ai.client import get_anthropic_client
from src.ai.prompts import build_messages, build_system_prompt
from src.ai.tavily import execute_tavily_search
from src.config import get_settings
from src.exceptions import APIError

logger = logging.getLogger(__name__)

_TAVILY_TOOL_NAME = "tavily_search"
_TAVILY_SEARCH_TOOL = {
    "name": _TAVILY_TOOL_NAME,
    "description": (
        "Search trusted medical web sources. Use this tool multiple times with long-tail "
        "queries, not just one query. Cover differential diagnosis, red flags, treatment, "
        "and medication safety when relevant."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": (
                    "Specific long-tail query for medical evidence. Include population, "
                    "symptom context, and intent."
                ),
            },
            "search_depth": {
                "type": "string",
                "enum": ["basic", "advanced"],
                "description": "Use advanced unless speed is critical.",
            },
            "include_answer": {
                "type": "string",
                "enum": ["basic", "advanced"],
                "description": "Use advanced to get richer synthesis.",
            },
            "include_favicon": {"type": "boolean"},
            "max_results": {"type": "integer", "minimum": 1, "maximum": 10},
        },
        "required": ["query"],
    },
}

_CREATE_RETRY_ATTEMPTS = 2


def _chunk_text(text: str, chunk_size: int) -> list[str]:
    if not text:
        return []
    return [text[i : i + chunk_size] for i in range(0, len(text), chunk_size)]


def _extract_text_blocks(content_blocks: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for block in content_blocks:
        if block.get("type") == "text" and isinstance(block.get("text"), str):
            parts.append(str(block.get("text")))
    return "".join(parts).strip()


def _coerce_content_block(block: object) -> dict[str, Any] | None:
    if isinstance(block, dict):
        block_type = block.get("type")
        if block_type == "text":
            return {"type": "text", "text": str(block.get("text") or "")}
        if block_type == "tool_use":
            return {
                "type": "tool_use",
                "id": str(block.get("id") or ""),
                "name": str(block.get("name") or ""),
                "input": block.get("input") if isinstance(block.get("input"), dict) else {},
            }
        return None

    block_type = getattr(block, "type", "")
    if block_type == "text":
        return {"type": "text", "text": str(getattr(block, "text", "") or "")}
    if block_type == "tool_use":
        tool_input = getattr(block, "input", {})
        return {
            "type": "tool_use",
            "id": str(getattr(block, "id", "") or ""),
            "name": str(getattr(block, "name", "") or ""),
            "input": tool_input if isinstance(tool_input, dict) else {},
        }
    return None


def _extract_response_content(response: object) -> list[dict[str, Any]]:
    content_blocks = getattr(response, "content", []) or []
    normalized_blocks: list[dict[str, Any]] = []
    for block in content_blocks:
        normalized = _coerce_content_block(block)
        if normalized:
            normalized_blocks.append(normalized)
    return normalized_blocks


def _extract_tool_calls(content_blocks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [block for block in content_blocks if block.get("type") == "tool_use"]


def _mock_response(question: str, v10_digest: str | None) -> str:
    context_hint = (
        "Given your existing health profile, this may relate to your current conditions [1]."
        if v10_digest
        else "Based on common clinical guidance, this could have multiple causes [1]."
    )

    question_lower = question.lower()
    if "chest pain" in question_lower or "can't breathe" in question_lower:
        return (
            "⚠️ IMPORTANT: Based on what you're describing, this could be a medical emergency. "
            "Please call 911 now or go to the nearest emergency room immediately.\n\n"
            f"{context_hint}\n\n"
            "**What to do next**\n"
            "- Call 911 now.\n"
            "- Do not drive yourself.\n"
            "- Keep emergency contacts informed.\n\n"
            "Sources:\n"
            "[1] Mayo Clinic - \"Heart attack\" (https://www.mayoclinic.org/diseases-conditions/heart-attack/)\n"
            "SAFETY_SIGNAL: {\"requiresEmergencyCare\": true, \"category\": \"cardiac\"}\n"
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
        "[1] Mayo Clinic - \"Dizziness\" (https://www.mayoclinic.org/symptoms/dizziness/)\n"
        "SAFETY_SIGNAL: {\"requiresEmergencyCare\": false, \"category\": \"none\"}\n"
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

    raw_retry_after = headers.get("retry-after") or headers.get("Retry-After")
    if not raw_retry_after:
        return None

    try:
        retry_after = int(float(raw_retry_after))
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

    if settings.ai_provider == "openrouter":
        return bool(settings.openrouter_api_key or settings.anthropic_api_key)

    return bool(settings.anthropic_api_key)


async def _create_message_with_retry(*, client: Any, request_kwargs: dict[str, Any]) -> object:
    last_exception: Exception | None = None
    for attempt in range(1, _CREATE_RETRY_ATTEMPTS + 1):
        try:
            return await client.messages.create(**request_kwargs)
        except anthropic.RateLimitError as exc:
            raise _rate_limited_error(exc) from exc
        except anthropic.APITimeoutError as exc:
            last_exception = exc
            if attempt < _CREATE_RETRY_ATTEMPTS:
                await asyncio.sleep(0.4)
                continue
            raise APIError(504, "AI_TIMEOUT", "AI response timed out.") from exc
        except Exception as exc:  # pragma: no cover - external API behavior
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


def _tool_query_preview(tool_call: dict[str, Any]) -> str:
    tool_input = tool_call.get("input")
    if not isinstance(tool_input, dict):
        return ""
    return str(tool_input.get("query") or "").strip()


async def _execute_tool_call(tool_call: dict[str, Any]) -> dict[str, Any]:
    tool_use_id = str(tool_call.get("id") or "")
    tool_name = str(tool_call.get("name") or "")
    tool_input = tool_call.get("input")
    if not isinstance(tool_input, dict):
        tool_input = {}

    if tool_name != _TAVILY_TOOL_NAME:
        error_payload = {
            "ok": False,
            "error": {
                "code": "UNKNOWN_TOOL",
                "message": f"Unsupported tool '{tool_name}'.",
            },
        }
        return {
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "is_error": True,
            "content": json.dumps(error_payload),
        }

    query = str(tool_input.get("query") or "").strip()
    if not query:
        error_payload = {
            "ok": False,
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "The search query cannot be empty.",
            },
        }
        return {
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "is_error": True,
            "content": json.dumps(error_payload),
        }

    try:
        search_payload = await execute_tavily_search(
            query=query,
            search_depth=(
                str(tool_input.get("search_depth"))
                if isinstance(tool_input.get("search_depth"), str)
                else None
            ),
            include_answer=(
                str(tool_input.get("include_answer"))
                if isinstance(tool_input.get("include_answer"), str)
                else None
            ),
            include_favicon=(
                bool(tool_input.get("include_favicon"))
                if isinstance(tool_input.get("include_favicon"), bool)
                else None
            ),
            max_results=(
                int(tool_input.get("max_results"))
                if isinstance(tool_input.get("max_results"), int)
                else None
            ),
        )
        payload = {"ok": True, "query": query, "search": search_payload}
        return {
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "content": json.dumps(payload),
        }
    except APIError as exc:
        if exc.code in {"SEARCH_BACKEND_UNAVAILABLE", "SEARCH_BACKEND_AUTH_ERROR"}:
            raise

        payload = {
            "ok": False,
            "query": query,
            "error": {"code": exc.code, "message": exc.message},
        }
        return {
            "type": "tool_result",
            "tool_use_id": tool_use_id,
            "is_error": True,
            "content": json.dumps(payload),
        }


async def generate_response_events(
    question: str,
    conversation_history: list[dict],
    v10_digest: str | None,
) -> AsyncIterator[dict]:
    settings = get_settings()

    if not _can_use_live_ai(settings):
        yield {"type": "tool_use", "tool": _TAVILY_TOOL_NAME, "status": "searching"}
        mock_text = _mock_response(question, v10_digest)
        for chunk in _chunk_text(mock_text, settings.sse_chunk_size):
            yield {"type": "token", "text": chunk}
        return

    system_prompt = build_system_prompt(v10_digest)
    messages: list[dict] = build_messages(
        conversation_history=conversation_history,
        user_question=question,
        max_history_messages=settings.max_conversation_context_messages,
    )
    client = get_anthropic_client()

    max_rounds = _parse_positive_int(getattr(settings, "ai_tool_max_rounds", None), fallback=6)
    min_tool_calls = _parse_positive_int(
        getattr(settings, "ai_tool_min_calls", None),
        fallback=3,
        allow_zero=True,
    )
    max_tool_calls = _parse_positive_int(getattr(settings, "ai_tool_max_calls", None), fallback=12)
    total_tool_calls = 0

    yield {"type": "tool_use", "tool": _TAVILY_TOOL_NAME, "status": "planning"}

    for _round_idx in range(max_rounds):
        response = await _create_message_with_retry(
            client=client,
            request_kwargs={
                "model": settings.anthropic_model,
                "max_tokens": settings.anthropic_max_tokens,
                "temperature": settings.ai_temperature,
                "system": system_prompt,
                "messages": cast(Any, messages),
                "tools": cast(Any, [_TAVILY_SEARCH_TOOL]),
                "tool_choice": {"type": "auto"},
            },
        )

        assistant_content = _extract_response_content(response)
        if not assistant_content:
            raise APIError(502, "AI_ERROR", "AI response contained no content.")

        tool_calls = _extract_tool_calls(assistant_content)
        if not tool_calls:
            if total_tool_calls < min_tool_calls:
                missing_calls = min_tool_calls - total_tool_calls
                messages.append({"role": "assistant", "content": cast(Any, assistant_content)})
                messages.append(
                    {
                        "role": "user",
                        "content": (
                            f"Before finalizing, call `{_TAVILY_TOOL_NAME}` at least "
                            f"{missing_calls} more time(s) with different long-tail "
                            "queries from trusted medical sources."
                        ),
                    }
                )
                continue

            final_text = _extract_text_blocks(assistant_content)
            if not final_text:
                raise APIError(502, "AI_ERROR", "AI response contained no text output.")
            for chunk in _chunk_text(final_text, settings.sse_chunk_size):
                yield {"type": "token", "text": chunk}
            return

        if total_tool_calls + len(tool_calls) > max_tool_calls:
            raise APIError(502, "AI_ERROR", "AI used too many search tool calls.")

        messages.append({"role": "assistant", "content": cast(Any, assistant_content)})

        tool_results: list[dict[str, Any]] = []
        for tool_call in tool_calls:
            total_tool_calls += 1
            query_preview = _tool_query_preview(tool_call)
            yield {
                "type": "tool_use",
                "tool": _TAVILY_TOOL_NAME,
                "status": "searching",
                "query": query_preview,
            }
            tool_results.append(await _execute_tool_call(tool_call))

        messages.append({"role": "user", "content": cast(Any, tool_results)})

    raise APIError(502, "AI_ERROR", "AI did not complete tool use within limits.")
