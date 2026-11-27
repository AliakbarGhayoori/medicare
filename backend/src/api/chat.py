from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import AsyncGenerator, AsyncIterator
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import StreamingResponse
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.ai.citations import citations_as_dicts, finalize_citations
from src.ai.safety import (
    CRISIS_RESOURCES,
    SafetySignalFilter,
    assess_confidence,
    extract_ai_safety_signal,
    requires_crisis_resources,
    resolve_emergency,
)
from src.ai.sources import SourceRegistry
from src.ai.stream import generate_response_events
from src.ai.v10_updater import update_v10_after_conversation
from src.config import get_settings
from src.dependencies.auth import AuthUser, get_current_user
from src.dependencies.database import get_db
from src.exceptions import APIError
from src.models.chat import (
    ChatRequest,
    ConversationListResponse,
    ConversationMessagesResponse,
    ConversationSummary,
    MessageResponse,
)
from src.services.analytics import track_event
from src.services.chat_service import (
    get_recent_messages_for_context,
    list_conversation_messages,
    list_conversations,
    resolve_conversation_id,
    save_message,
)
from src.services.profile_service import get_v10_digest, usable_digest
from src.services.settings_service import ensure_user_document
from src.services.usage_limits import Admission, UsageMeter, admit_question, new_meter, record_usage

logger = logging.getLogger(__name__)

router = APIRouter()

_background_tasks: set[asyncio.Task[object]] = set()


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, default=str)}\n\n"


def _log_task_exception(task: asyncio.Task[object]) -> None:
    """Callback attached to background tasks to log unhandled exceptions."""
    if task.cancelled():
        return
    exc = task.exception()
    if exc is not None:
        logger.error("Background task failed: %s", exc, exc_info=exc)


def _client_ip(request: Request) -> str | None:
    # The backend listens on 127.0.0.1 behind nginx, which sets X-Real-IP itself.
    forwarded = request.headers.get("x-real-ip", "").strip()
    if forwarded:
        return forwarded
    return request.client.host if request.client else None


async def _settle_usage(
    db: AsyncIOMotorDatabase, firebase_uid: str, meter: UsageMeter, admission: Admission
) -> None:
    try:
        await record_usage(db, firebase_uid, meter.total_usd, meter.searches)
    finally:
        admission.release()  # after recording, so the answer is always counted once


def _settle_usage_in_background(
    db: AsyncIOMotorDatabase, firebase_uid: str, meter: UsageMeter, admission: Admission
) -> None:
    # A task, not an await: this runs when the user leaves mid-answer too.
    task = asyncio.create_task(_settle_usage(db, firebase_uid, meter, admission))
    _background_tasks.add(task)
    task.add_done_callback(_background_tasks.discard)
    task.add_done_callback(_log_task_exception)


@router.post("/ask")
async def ask(
    payload: ChatRequest,
    request: Request,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> StreamingResponse:
    settings = get_settings()
    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)

    # Raises 429 (QUESTION_LIMIT / SERVICE_LIMIT) before anything is saved or spent.
    admission = await admit_question(db, user.uid, _client_ip(request))
    meter = new_meter(settings)
    try:
        conversation_id, history, v10_digest = await _prepare_question(db, user, payload)
    except BaseException:
        admission.release()
        raise

    async def event_generator() -> AsyncIterator[str]:
        answer = _answer_events(db, user, payload, conversation_id, history, v10_digest, meter)
        try:
            async for chunk in answer:
                yield chunk
        finally:
            try:
                # Close the answer first: an interrupted round adds its cost as it ends.
                await answer.aclose()
            finally:
                _settle_usage_in_background(db, user.uid, meter, admission)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


async def _prepare_question(
    db: AsyncIOMotorDatabase, user: AuthUser, payload: ChatRequest
) -> tuple[str, list[dict], str | None]:
    """Save the question; return its conversation, the earlier messages and the profile."""
    settings = get_settings()

    conversation_id = await resolve_conversation_id(
        db=db,
        firebase_uid=user.uid,
        question=payload.question,
        conversation_id=payload.conversation_id,
    )

    history = await get_recent_messages_for_context(
        db=db,
        firebase_uid=user.uid,
        conversation_id=conversation_id,
        limit=settings.max_conversation_context_messages,
    )

    v10_doc = await get_v10_digest(db, firebase_uid=user.uid)
    v10_digest = usable_digest(v10_doc)

    await save_message(
        db=db,
        firebase_uid=user.uid,
        conversation_id=conversation_id,
        role="user",
        content=payload.question,
    )

    await track_event(
        db,
        "question_asked",
        user.uid,
        {
            "conversationId": conversation_id,
            "hasV10Context": bool(v10_digest),
        },
    )

    return conversation_id, history, v10_digest


async def _answer_events(
    db: AsyncIOMotorDatabase,
    user: AuthUser,
    payload: ChatRequest,
    conversation_id: str,
    history: list[dict],
    v10_digest: str | None,
    meter: UsageMeter,
) -> AsyncGenerator[str, None]:
    settings = get_settings()
    full_text = ""
    signal_filter = SafetySignalFilter()
    sources = SourceRegistry()
    stream_started = time.monotonic()
    first_token_ms: int | None = None
    try:
        async for event in generate_response_events(
            question=payload.question,
            conversation_history=history,
            v10_digest=v10_digest,
            sources=sources,
            answer_format=payload.answer_format,
            meter=meter,
        ):
            event_type = event.get("type")
            if event_type == "token":
                chunk = str(event.get("text", ""))
                full_text += chunk
                visible = signal_filter.feed(chunk)
                if not visible:
                    continue
                if first_token_ms is None:
                    first_token_ms = int((time.monotonic() - stream_started) * 1000)
                yield _sse("token", {"text": visible})
            elif event_type == "tool_use":
                yield _sse(
                    "tool_use",
                    {
                        "tool": event.get("tool", "tavily_search"),
                        "status": event.get("status", "searching"),
                        "query": event.get("query"),
                    },
                )

        tail = signal_filter.flush()
        if tail:
            yield _sse("token", {"text": tail})

        signaled_text, ai_requires, ai_category = extract_ai_safety_signal(full_text)
        clean_text, citations = finalize_citations(signaled_text, sources)
        requires_emergency_care, emergency_category = resolve_emergency(
            payload.question, ai_requires, ai_category
        )
        confidence = assess_confidence(clean_text, citations)

        # The user's own words count too: a missed crisis costs far more than an
        # extra helpline block on a question that only mentions self-harm.
        wants_crisis_help = emergency_category == "self_harm" or requires_crisis_resources(
            payload.question
        )
        if wants_crisis_help and not ("988" in clean_text or "findahelpline.com" in clean_text):
            clean_text = f"{clean_text}{CRISIS_RESOURCES}"

        message_id = await save_message(
            db=db,
            firebase_uid=user.uid,
            conversation_id=conversation_id,
            role="assistant",
            content=clean_text,
            citations=citations_as_dicts(citations),
            confidence=confidence,
            requires_emergency_care=requires_emergency_care,
        )

        if settings.v10_auto_update_enabled:
            task = asyncio.create_task(
                update_v10_after_conversation(
                    db=db,
                    firebase_uid=user.uid,
                    user_question=payload.question,
                    assistant_response=clean_text,
                )
            )
            task.add_done_callback(_log_task_exception)

        total_response_ms = int((time.monotonic() - stream_started) * 1000)
        logger.info(
            "chat_response_complete",
            extra={
                "endpoint": "/api/chat/ask",
                "latency_ms": total_response_ms,
                "event": "chat_response_complete",
                "properties": {
                    "citationCount": len(citations),
                    "firstTokenMs": first_token_ms,
                    "requiresEmergencyCare": requires_emergency_care,
                    "confidence": confidence,
                },
            },
        )
        await track_event(
            db,
            "response_received",
            user.uid,
            {
                "conversationId": conversation_id,
                "confidence": confidence,
                "citationCount": len(citations),
                "hasEmergency": requires_emergency_care,
                "responseTimeMs": total_response_ms,
                "firstTokenMs": first_token_ms,
            },
        )

        if requires_emergency_care:
            await track_event(
                db,
                "emergency_detected",
                user.uid,
                {
                    "conversationId": conversation_id,
                    "category": emergency_category or "general",
                },
            )

        yield _sse(
            "done",
            {
                "messageId": message_id,
                "conversationId": conversation_id,
                "content": clean_text,
                "citations": citations_as_dicts(citations),
                "confidence": confidence,
                "requiresEmergencyCare": requires_emergency_care,
            },
        )
    except APIError as exc:
        await track_event(
            db,
            "error_occurred",
            user.uid,
            {"endpoint": "/api/chat/ask", "code": exc.code},
        )
        yield _sse("error", {"code": exc.code, "message": exc.message})
    except Exception:
        await track_event(
            db,
            "error_occurred",
            user.uid,
            {"endpoint": "/api/chat/ask", "code": "INTERNAL_ERROR"},
        )
        logger.exception("Unhandled chat streaming error")
        yield _sse(
            "error",
            {
                "code": "INTERNAL_ERROR",
                "message": "Something went wrong generating your answer.",
            },
        )


@router.get("/history", response_model=ConversationListResponse)
async def get_history(
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
    before: str | None = None,
) -> ConversationListResponse:
    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)

    conversations, has_more, next_cursor = await list_conversations(
        db=db,
        firebase_uid=user.uid,
        limit=limit,
        before=before,
    )

    return ConversationListResponse(
        conversations=[ConversationSummary(**item) for item in conversations],
        hasMore=has_more,
        nextCursor=next_cursor,
    )


@router.get("/history/{conversation_id}", response_model=ConversationMessagesResponse)
async def get_conversation(
    conversation_id: str,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    before: str | None = None,
) -> ConversationMessagesResponse:
    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)

    messages, has_more, next_cursor = await list_conversation_messages(
        db=db,
        firebase_uid=user.uid,
        conversation_id=conversation_id,
        limit=limit,
        before=before,
    )

    return ConversationMessagesResponse(
        conversationId=conversation_id,
        messages=[MessageResponse(**item) for item in messages],
        hasMore=has_more,
        nextCursor=next_cursor,
    )
