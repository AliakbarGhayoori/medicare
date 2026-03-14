from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from motor.motor_asyncio import AsyncIOMotorDatabase

from src.ai.citations import citations_as_dicts, extract_citations_from_response, validate_citations
from src.ai.safety import assess_confidence, extract_ai_safety_signal
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
from src.services.profile_service import get_v10_digest
from src.services.rate_limiter import check_rate_limit_with_retry
from src.services.settings_service import ensure_user_document

logger = logging.getLogger(__name__)

router = APIRouter()


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, default=str)}\n\n"


def _log_task_exception(task: asyncio.Task[object]) -> None:
    """Callback attached to background tasks to log unhandled exceptions."""
    if task.cancelled():
        return
    exc = task.exception()
    if exc is not None:
        logger.error("Background task failed: %s", exc, exc_info=exc)


@router.post("/ask")
async def ask(
    payload: ChatRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> StreamingResponse:
    settings = get_settings()
    allowed, retry_after = check_rate_limit_with_retry(
        f"chat:{user.uid}",
        max_requests=settings.chat_rate_limit_per_hour,
        window_seconds=3600,
    )
    if not allowed:
        raise APIError(
            429,
            "RATE_LIMITED",
            "Chat rate limit exceeded. Please try again later.",
            headers={"Retry-After": str(retry_after)},
        )

    await ensure_user_document(db, firebase_uid=user.uid, email=user.email)

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
    v10_digest = v10_doc.get("digest") if v10_doc else None

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

    async def event_generator() -> AsyncIterator[str]:
        full_text = ""
        stream_started = time.monotonic()
        first_token_ms: int | None = None
        try:
            async for event in generate_response_events(
                question=payload.question,
                conversation_history=history,
                v10_digest=v10_digest,
            ):
                event_type = event.get("type")
                if event_type == "token":
                    chunk = str(event.get("text", ""))
                    full_text += chunk
                    if first_token_ms is None:
                        first_token_ms = int((time.monotonic() - stream_started) * 1000)
                    yield _sse("token", {"text": chunk})
                elif event_type == "tool_use":
                    yield _sse(
                        "tool_use",
                        {
                            "tool": event.get("tool", "tavily_search"),
                            "status": event.get("status", "searching"),
                            "query": event.get("query"),
                        },
                    )

            signaled_text, requires_emergency_care, emergency_category = extract_ai_safety_signal(
                full_text
            )
            clean_text, citations = extract_citations_from_response(signaled_text)
            citations = validate_citations(clean_text, citations)
            confidence = assess_confidence(clean_text, citations)

            if emergency_category == "self_harm":
                crisis_block = (
                    "\n\nCrisis support resources:\n"
                    "- Call or text 988 (Suicide & Crisis Lifeline)\n"
                    "- Crisis Text Line: text HOME to 741741\n"
                    "- If in immediate danger, call 911 now."
                )
                if "988" not in clean_text:
                    clean_text = f"{clean_text}{crisis_block}"

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

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
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
