from __future__ import annotations

import logging
import re
from typing import Any, cast

from motor.motor_asyncio import AsyncIOMotorDatabase

from src.ai.client import get_anthropic_client
from src.ai.prompts import V10_UPDATE_SYSTEM_PROMPT, V10_UPDATE_USER_TEMPLATE
from src.config import get_settings
from src.services.profile_service import get_v10_digest, upsert_v10_digest
from src.utils import utcnow

logger = logging.getLogger(__name__)

_NON_MEDICAL_PATTERNS = [
    r"^(thanks?|thank you|ok|okay|got it|great|bye|goodbye)\s*[!.]*$",
]


def should_update_v10(user_question: str) -> bool:
    question = user_question.strip().lower()
    return not any(re.match(pattern, question) for pattern in _NON_MEDICAL_PATTERNS)


def _extract_response_text(response: object) -> str:
    content_blocks = getattr(response, "content", []) or []
    parts: list[str] = []
    for block in content_blocks:
        text = getattr(block, "text", None)
        if isinstance(text, str):
            parts.append(text)
    return "".join(parts).strip()


def _heuristic_digest_update(current_digest: str, user_question: str) -> str:
    now_label = utcnow().strftime("%Y-%m-%d")

    if not current_digest:
        next_digest = f"Recent concerns ({now_label}): {user_question.strip()}"
    else:
        next_digest = f"{current_digest}\nRecent concerns ({now_label}): {user_question.strip()}"

    return next_digest[:5000]


def _can_use_ai_update() -> bool:
    settings = get_settings()

    if settings.mock_ai:
        return False

    if settings.ai_provider == "openrouter":
        return bool(settings.openrouter_api_key or settings.anthropic_api_key)

    return bool(settings.anthropic_api_key)


async def _update_digest_with_ai(
    current_digest: str,
    user_question: str,
    assistant_response: str,
) -> str:
    settings = get_settings()
    client = get_anthropic_client()

    prompt = V10_UPDATE_USER_TEMPLATE.format(
        current_digest=current_digest or "(No health profile set up yet)",
        user_question=user_question,
        assistant_response=assistant_response[:1200],
    )

    response = await client.messages.create(
        model=settings.anthropic_model,
        max_tokens=600,
        temperature=0.1,
        system=V10_UPDATE_SYSTEM_PROMPT,
        messages=cast(Any, [{"role": "user", "content": prompt}]),
    )

    return _extract_response_text(response)[:5000]


async def update_v10_after_conversation(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    user_question: str,
    assistant_response: str,
) -> bool:
    if not should_update_v10(user_question):
        return False

    existing = await get_v10_digest(db, firebase_uid)
    current_digest = (existing or {}).get("digest", "")

    if user_question in current_digest:
        return False

    next_digest = ""

    if _can_use_ai_update():
        try:
            next_digest = await _update_digest_with_ai(
                current_digest=current_digest,
                user_question=user_question,
                assistant_response=assistant_response,
            )
        except Exception:
            logger.warning("V10 AI update failed, falling back to heuristic", exc_info=True)
            next_digest = ""

    if not next_digest:
        next_digest = _heuristic_digest_update(
            current_digest=current_digest,
            user_question=user_question,
        )

    if not next_digest or next_digest == current_digest:
        return False

    await upsert_v10_digest(db, firebase_uid=firebase_uid, digest=next_digest, source="auto")
    return True
