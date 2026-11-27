from __future__ import annotations

import logging
import re

from motor.motor_asyncio import AsyncIOMotorDatabase

from src.ai.client import chat_model_options, get_openai_client, reported_cost
from src.ai.prompts import V10_UPDATE_SYSTEM_PROMPT, V10_UPDATE_USER_TEMPLATE
from src.config import get_settings
from src.services.profile_service import get_v10_digest, upsert_v10_digest, usable_digest
from src.services.usage_limits import record_usage, service_has_budget
from src.utils import utcnow

logger = logging.getLogger(__name__)

_NON_MEDICAL_PATTERNS = [
    r"^(thanks?|thank you|ok|okay|got it|great|bye|goodbye)\s*[!.]*$",
]
_MAX_DIGEST_CHARS = 5000
# Reasoning models spend part of max_tokens on thinking before the profile text.
_MAX_UPDATE_TOKENS = 3000
# At most ~3,000 output tokens plus a short prompt: about $0.05 with gemini-4-neon.
_UPDATE_COST_RESERVE_USD = 0.06
_UNMETERED_UPDATE_COST_USD = 0.02  # charged when OpenRouter reports no cost
_MAX_CONTEXT_ANSWER_CHARS = 1200
_NO_CHANGE = "NO_CHANGE"


def should_update_v10(user_question: str) -> bool:
    question = user_question.strip().lower()
    return not any(re.match(pattern, question) for pattern in _NON_MEDICAL_PATTERNS)


def _heuristic_digest_update(current_digest: str, user_question: str) -> str:
    now_label = utcnow().strftime("%Y-%m-%d")

    if not current_digest:
        next_digest = f"Recent concerns ({now_label}): {user_question.strip()}"
    else:
        next_digest = f"{current_digest}\nRecent concerns ({now_label}): {user_question.strip()}"

    return next_digest[:_MAX_DIGEST_CHARS]


def _can_use_ai_update() -> bool:
    settings = get_settings()
    if settings.mock_ai:
        return False
    return bool(settings.openrouter_api_key or settings.anthropic_api_key)


def _is_no_change(reply: str) -> bool:
    """Any reply whose first line says "no change" counts, so a chatty near-miss
    ("NO_CHANGE - nothing new", "No changes.") never overwrites the profile."""
    first_line = next((line for line in reply.splitlines() if line.strip()), "")
    key = re.sub(r"[\s\-]+", "_", first_line.strip().strip("`*_.\"' ").upper())
    return key.startswith(_NO_CHANGE)


async def _ask_model_for_digest(
    current_digest: str,
    user_question: str,
    assistant_response: str,
) -> tuple[str, str | None, float | None]:
    """Return the model's reply text, its finish reason and the reported cost."""
    settings = get_settings()
    client = get_openai_client()

    prompt = V10_UPDATE_USER_TEMPLATE.format(
        today=utcnow().strftime("%Y-%m-%d"),
        current_digest=current_digest,
        user_question=user_question,
        assistant_response=assistant_response[:_MAX_CONTEXT_ANSWER_CHARS],
    )

    response = await client.chat.completions.create(
        **chat_model_options(settings),
        max_tokens=_MAX_UPDATE_TOKENS,
        temperature=0.1,
        messages=[
            {"role": "system", "content": V10_UPDATE_SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
    )

    choice = response.choices[0]
    return (
        (choice.message.content or "").strip(),
        getattr(choice, "finish_reason", None),
        reported_cost(getattr(response, "usage", None)),
    )


def _skip(reason: str) -> bool:
    logger.info("v10_update_skip reason=%s", reason)
    return False


async def update_v10_after_conversation(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    user_question: str,
    assistant_response: str,
) -> bool:
    """Update the stored health profile from one exchange. Logs never contain text."""
    if not should_update_v10(user_question):
        return _skip("non_medical")

    current_digest = usable_digest(await get_v10_digest(db, firebase_uid)) or ""

    if _can_use_ai_update():
        if not await service_has_budget(db, _UPDATE_COST_RESERVE_USD):
            return _skip("budget_spent")
        try:
            reply, finish_reason, cost = await _ask_model_for_digest(
                current_digest=current_digest,
                user_question=user_question,
                assistant_response=assistant_response,
            )
        except Exception as exc:
            logger.warning("v10_update_skip reason=ai_error error=%s", type(exc).__name__)
            return False
        await record_usage(db, firebase_uid, _UNMETERED_UPDATE_COST_USD if cost is None else cost)
        if finish_reason == "length":
            return _skip("truncated")
        if _is_no_change(reply):
            return _skip("no_change")
        next_digest = usable_digest({"digest": reply})
        if next_digest is None:
            return _skip("empty_or_placeholder")
        if len(next_digest) > _MAX_DIGEST_CHARS:
            return _skip("too_long")
    else:
        # Mock mode or no API key: keep a simple local record for development.
        if user_question in current_digest:
            return _skip("already_in_digest")
        next_digest = _heuristic_digest_update(current_digest, user_question)

    if next_digest == current_digest:
        return _skip("no_change")

    await upsert_v10_digest(db, firebase_uid=firebase_uid, digest=next_digest, source="auto")
    logger.info(
        "v10_update_saved source=auto previous_len=%d new_len=%d",
        len(current_digest),
        len(next_digest),
    )
    return True
