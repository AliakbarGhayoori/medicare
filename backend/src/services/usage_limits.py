"""Question and spending limits: per user, per internet address, and for the service.

Every answer is admitted before any AI call. A user may ask a few questions an hour
and a day and spend a small share of the month's budget; one internet address may
not ask more than a set number of questions an hour across accounts; and the whole
service stops answering once its daily or monthly budget is spent.

Spending is counted from what the answer actually cost (the model's cost reported
by OpenRouter plus the web searches at Tavily's pay-as-you-go price), in the
``usageCounters`` collection:

- ``service:month:YYYY-MM`` and ``service:day:YYYY-MM-DD``: the whole service;
- ``user:<uid>:month:YYYY-MM`` and ``user:<uid>:day:YYYY-MM-DD``: one user
  (deleted with the account).

An answer's cost is known only when it ends, so each admitted answer holds back
``question_cost_reserve_usd`` of the budget until then. A reservation lives in
memory (the backend runs one process) and expires on its own, so a lost one can
never block the service for long.
"""

from __future__ import annotations

import logging
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ReturnDocument

from src.config import get_settings
from src.exceptions import APIError
from src.services.rate_limiter import check_rate_limit_with_retry
from src.utils import utcnow

logger = logging.getLogger(__name__)

QUESTION_LIMIT = "QUESTION_LIMIT"  # this user or address has asked enough for now
SERVICE_LIMIT = "SERVICE_LIMIT"  # the service's budget is spent

_RESERVATION_TTL_SECONDS = 15 * 60  # longer than the longest possible answer
_DAY_DOC_DAYS = 40
_USER_MONTH_DOC_DAYS = 400
_EMERGENCY = "In an emergency, call your local emergency number."

_monotonic = time.monotonic
_reservations: dict[str, tuple[float, float]] = {}  # id -> (dollars, started)


@dataclass
class UsageMeter:
    """What one answer has cost so far."""

    search_cost_usd: float = 0.0
    model_cost_usd: float = 0.0
    searches: int = 0

    def add_model_cost(self, usd: float) -> None:
        self.model_cost_usd += max(0.0, usd)

    def add_searches(self, count: int) -> None:
        self.searches += max(0, count)

    @property
    def total_usd(self) -> float:
        return self.model_cost_usd + self.searches * self.search_cost_usd


def new_meter(settings: Any) -> UsageMeter:
    credits = 2 if str(settings.tavily_search_depth).lower() == "advanced" else 1
    return UsageMeter(search_cost_usd=credits * settings.tavily_cost_per_credit_usd)


@dataclass
class Admission:
    """An admitted answer. Call ``release()`` once its cost is recorded."""

    reservation_id: str

    def release(self) -> None:
        _reservations.pop(self.reservation_id, None)


# --- Periods ----------------------------------------------------------------------


def _month(now: datetime) -> str:
    return now.strftime("%Y-%m")


def _day(now: datetime) -> str:
    return now.strftime("%Y-%m-%d")


def _next_day(now: datetime) -> datetime:
    return (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)


def _next_month(now: datetime) -> datetime:
    year, month = (now.year + 1, 1) if now.month == 12 else (now.year, now.month + 1)
    return now.replace(year=year, month=month, day=1, hour=0, minute=0, second=0, microsecond=0)


def _seconds_until(moment: datetime, now: datetime) -> int:
    return max(1, int((moment - now).total_seconds()))


def _service_ids(now: datetime) -> dict[str, str]:
    return {
        "service_month": f"service:month:{_month(now)}",
        "service_day": f"service:day:{_day(now)}",
    }


def _ids(firebase_uid: str, now: datetime) -> dict[str, str]:
    return {
        **_service_ids(now),
        "user_month": f"user:{firebase_uid}:month:{_month(now)}",
        "user_day": f"user:{firebase_uid}:day:{_day(now)}",
    }


def _wait_text(seconds: int) -> str:
    minutes = max(1, round(seconds / 60))
    if minutes < 90:
        return f"about {minutes} minute{'s' if minutes != 1 else ''}"
    return f"about {round(minutes / 60)} hours"


def _refuse(code: str, message: str, retry_after: int) -> APIError:
    return APIError(429, code, message, headers={"Retry-After": str(retry_after)})


# --- Reservations -----------------------------------------------------------------


def _reserved_usd() -> float:
    cutoff = _monotonic() - _RESERVATION_TTL_SECONDS
    for key in [k for k, (_, started) in _reservations.items() if started < cutoff]:
        _reservations.pop(key, None)
    return sum(amount for amount, _ in _reservations.values())


async def _costs(db: AsyncIOMotorDatabase, ids: list[str]) -> dict[str, dict]:
    docs = await db.usageCounters.find({"_id": {"$in": ids}}).to_list(length=len(ids))
    return {doc["_id"]: doc for doc in docs}


def _cost(docs: dict[str, dict], doc_id: str) -> float:
    return float(docs.get(doc_id, {}).get("costUsd", 0.0))


def _service_refusal(
    docs: dict[str, dict], ids: dict[str, str], amount: float, now: datetime
) -> APIError | None:
    settings = get_settings()
    held = _reserved_usd() + amount
    if _cost(docs, ids["service_month"]) + held > settings.monthly_budget_usd:
        reopens = _next_month(now)
        return _refuse(
            SERVICE_LIMIT,
            "MediCare AI has reached its limit for this month and can't answer new "
            f"questions until {reopens.strftime('%B')} {reopens.day}. {_EMERGENCY}",
            _seconds_until(reopens, now),
        )
    if _cost(docs, ids["service_day"]) + held > settings.daily_budget_usd:
        wait = _seconds_until(_next_day(now), now)
        return _refuse(
            SERVICE_LIMIT,
            "MediCare AI is very busy today and can't answer new questions right now. "
            f"Please try again in {_wait_text(wait)}. {_EMERGENCY}",
            wait,
        )
    return None


async def service_has_budget(
    db: AsyncIOMotorDatabase, amount_usd: float, now: datetime | None = None
) -> bool:
    """Whether the service may spend ``amount_usd`` more (answers in progress count)."""
    now = now or utcnow()
    ids = _service_ids(now)
    docs = await _costs(db, list(ids.values()))
    return _service_refusal(docs, ids, amount_usd, now) is None


# --- Admission --------------------------------------------------------------------


async def admit_question(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    client_ip: str | None,
    now: datetime | None = None,
) -> Admission:
    """Admit one question or raise a 429 ``APIError`` saying when to try again."""
    settings = get_settings()
    now = now or utcnow()
    ids = _ids(firebase_uid, now)
    docs = await _costs(db, list(ids.values()))

    asked_today = int(docs.get(ids["user_day"], {}).get("questions", 0))
    if asked_today >= settings.chat_questions_per_day:
        wait = _seconds_until(_next_day(now), now)
        raise _refuse(
            QUESTION_LIMIT,
            f"You've reached today's limit of {settings.chat_questions_per_day} questions. "
            f"You can ask more in {_wait_text(wait)}.",
            wait,
        )
    if _cost(docs, ids["user_month"]) >= settings.user_monthly_budget_usd:
        reopens = _next_month(now)
        raise _refuse(
            QUESTION_LIMIT,
            "You've reached this month's limit for your account. You can ask again on "
            f"{reopens.strftime('%B')} {reopens.day}. {_EMERGENCY}",
            _seconds_until(reopens, now),
        )
    refusal = _service_refusal(docs, ids, settings.question_cost_reserve_usd, now)
    if refusal is not None:
        logger.warning("usage_limit service_budget_spent code=%s", refusal.code)
        raise refusal

    if client_ip:
        allowed, wait = check_rate_limit_with_retry(
            f"ip:{client_ip}", max_requests=settings.ip_questions_per_hour, window_seconds=3600
        )
        if not allowed:
            raise _refuse(
                QUESTION_LIMIT,
                "Too many questions have been sent from this network in the last hour. "
                f"Please try again in {_wait_text(wait)}.",
                wait,
            )
    allowed, wait = check_rate_limit_with_retry(
        f"chat:{firebase_uid}", max_requests=settings.chat_rate_limit_per_hour, window_seconds=3600
    )
    if not allowed:
        raise _refuse(
            QUESTION_LIMIT,
            f"You've asked {settings.chat_rate_limit_per_hour} questions in the last hour. "
            f"You can ask again in {_wait_text(wait)}.",
            wait,
        )

    reservation_id = uuid.uuid4().hex
    _reservations[reservation_id] = (settings.question_cost_reserve_usd, _monotonic())
    await _add(db, firebase_uid, now, {"questions": 1})
    return Admission(reservation_id)


# --- Recording --------------------------------------------------------------------


async def _add(
    db: AsyncIOMotorDatabase, firebase_uid: str, now: datetime, inc: dict[str, float]
) -> dict | None:
    """Add to the four counters; return the service's month counter after the update."""
    ids = _ids(firebase_uid, now)
    expiry = {
        "service_day": now + timedelta(days=_DAY_DOC_DAYS),
        "user_day": now + timedelta(days=_DAY_DOC_DAYS),
        "user_month": now + timedelta(days=_USER_MONTH_DOC_DAYS),
    }
    month_doc = None
    for key, doc_id in ids.items():
        on_insert: dict[str, Any] = {}
        if key.startswith("user"):
            on_insert["firebaseUid"] = firebase_uid
        if key in expiry:
            on_insert["expiresAt"] = expiry[key]
        update: dict[str, Any] = {"$inc": inc, "$set": {"updatedAt": now}}
        if on_insert:
            update["$setOnInsert"] = on_insert
        if key == "service_month":
            month_doc = await db.usageCounters.find_one_and_update(
                {"_id": doc_id}, update, upsert=True, return_document=ReturnDocument.AFTER
            )
        else:
            await db.usageCounters.update_one({"_id": doc_id}, update, upsert=True)
    return month_doc


async def record_usage(
    db: AsyncIOMotorDatabase,
    firebase_uid: str,
    cost_usd: float,
    searches: int = 0,
    now: datetime | None = None,
) -> None:
    """Add what one AI call or answer cost to the user's and the service's totals."""
    if cost_usd <= 0 and searches <= 0:
        return
    settings = get_settings()
    inc: dict[str, float] = {"costUsd": round(max(0.0, cost_usd), 6)}
    if searches:
        inc["searches"] = searches
    month = await _add(db, firebase_uid, now or utcnow(), inc)
    spent = float((month or {}).get("costUsd", 0.0))
    log = logger.warning if spent >= 0.8 * settings.monthly_budget_usd else logger.info
    log(
        "usage_recorded cost=%.4f searches=%d month_total=%.2f month_budget=%.2f",
        cost_usd,
        searches,
        spent,
        settings.monthly_budget_usd,
    )
