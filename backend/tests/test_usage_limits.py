from __future__ import annotations

import asyncio
from datetime import UTC, datetime

import pytest

from src.config import get_settings
from src.exceptions import APIError
from src.services import usage_limits
from src.services.usage_limits import UsageMeter, admit_question, record_usage

_NOW = datetime(2026, 11, 27, 18, 30, tzinfo=UTC)
_MONTH = "2026-11"
_DAY = "2026-11-27"


def _ask(api_client, uid: str = "test_uid", ip: str | None = None):  # noqa: ANN001, ANN202
    headers = {"Authorization": f"Bearer mock:{uid}", "Accept": "text/event-stream"}
    if ip:
        headers["X-Real-IP"] = ip
    return api_client.post("/api/chat/ask", headers=headers, json={"question": "Is tea ok?"})


async def _seed(mock_db, doc_id: str, **fields) -> None:  # noqa: ANN001, ANN003
    await mock_db.usageCounters.update_one({"_id": doc_id}, {"$set": fields}, upsert=True)


async def _doc(mock_db, doc_id: str, attempts: int = 100) -> dict | None:  # noqa: ANN001
    """Usage is written by a background task after the answer; wait for it briefly."""
    for _ in range(attempts):
        doc = await mock_db.usageCounters.find_one({"_id": doc_id})
        if doc and doc.get("costUsd"):
            return doc
        await asyncio.sleep(0.01)
    return await mock_db.usageCounters.find_one({"_id": doc_id})


def _this_month() -> str:
    return datetime.now(UTC).strftime("%Y-%m")


def _today() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%d")


# --- Per-user and per-address limits through the API ------------------------------


async def test_daily_question_limit_refuses_with_a_readable_message(
    api_client, monkeypatch
) -> None:
    monkeypatch.setattr(get_settings(), "chat_questions_per_day", 2)

    assert (await _ask(api_client)).status_code == 200
    assert (await _ask(api_client)).status_code == 200
    refused = await _ask(api_client)

    assert refused.status_code == 429
    error = refused.json()["error"]
    assert error["code"] == "QUESTION_LIMIT"
    assert "today's limit of 2 questions" in error["message"]
    assert 0 < int(refused.headers["Retry-After"]) <= 86400


async def test_hourly_limit_names_the_wait_in_minutes(api_client, monkeypatch) -> None:
    monkeypatch.setattr(get_settings(), "chat_rate_limit_per_hour", 1)

    assert (await _ask(api_client)).status_code == 200
    refused = await _ask(api_client)

    assert refused.status_code == 429
    error = refused.json()["error"]
    assert error["code"] == "QUESTION_LIMIT"
    assert "in the last hour" in error["message"]
    assert "minutes" in error["message"]


async def test_one_address_is_limited_across_many_accounts(api_client, monkeypatch) -> None:
    monkeypatch.setattr(get_settings(), "ip_questions_per_hour", 2)

    assert (await _ask(api_client, "uid_a", ip="203.0.113.7")).status_code == 200
    assert (await _ask(api_client, "uid_b", ip="203.0.113.7")).status_code == 200
    refused = await _ask(api_client, "uid_c", ip="203.0.113.7")
    other_address = await _ask(api_client, "uid_c", ip="198.51.100.9")

    assert refused.status_code == 429
    assert refused.json()["error"]["code"] == "QUESTION_LIMIT"
    assert other_address.status_code == 200


async def test_user_monthly_budget_refuses_that_user_only(api_client, mock_db) -> None:
    await _seed(
        mock_db, f"user:test_uid:month:{_this_month()}", firebaseUid="test_uid", costUsd=2.5
    )

    refused = await _ask(api_client)
    other_user = await _ask(api_client, "uid_other")

    assert refused.status_code == 429
    assert refused.json()["error"]["code"] == "QUESTION_LIMIT"
    assert "this month" in refused.json()["error"]["message"]
    assert other_user.status_code == 200


async def test_spent_monthly_budget_pauses_the_service(api_client, mock_db) -> None:
    await _seed(mock_db, f"service:month:{_this_month()}", costUsd=9.6)

    refused = await _ask(api_client)

    assert refused.status_code == 429
    error = refused.json()["error"]
    assert error["code"] == "SERVICE_LIMIT"
    assert "emergency" in error["message"]
    assert int(refused.headers["Retry-After"]) > 0


async def test_spent_daily_budget_pauses_the_service(api_client, mock_db) -> None:
    await _seed(mock_db, f"service:day:{_today()}", costUsd=2.0)

    refused = await _ask(api_client)

    assert refused.status_code == 429
    assert refused.json()["error"]["code"] == "SERVICE_LIMIT"


async def test_refused_question_never_reaches_the_ai(api_client, mock_db, monkeypatch) -> None:
    from src.api import chat as chat_api

    await _seed(mock_db, f"service:month:{_this_month()}", costUsd=10.0)
    calls: list[str] = []

    async def _never(**kwargs):  # noqa: ANN003, ANN202
        calls.append(kwargs["question"])
        yield {"type": "token", "text": "x"}

    monkeypatch.setattr(chat_api, "generate_response_events", _never)

    assert (await _ask(api_client)).status_code == 429
    assert calls == []
    assert await mock_db.messages.count_documents({}) == 0


async def test_answer_cost_is_recorded_for_user_and_service(
    api_client, mock_db, monkeypatch
) -> None:
    from src.api import chat as chat_api

    async def _costly(**kwargs):  # noqa: ANN003, ANN202
        meter = kwargs["meter"]
        meter.add_model_cost(0.12)
        meter.add_searches(2)
        yield {"type": "token", "text": "Tea is fine [1]."}

    monkeypatch.setattr(chat_api, "generate_response_events", _costly)

    response = await _ask(api_client)
    assert response.status_code == 200
    assert "event: done" in response.text

    expected = 0.12 + 2 * 0.016
    month = await _doc(mock_db, f"service:month:{_this_month()}")
    day = await _doc(mock_db, f"service:day:{_today()}")
    user_month = await _doc(mock_db, f"user:test_uid:month:{_this_month()}")
    user_day = await _doc(mock_db, f"user:test_uid:day:{_today()}")
    for doc in (month, day, user_month, user_day):
        assert doc is not None
        assert doc["costUsd"] == pytest.approx(expected)
        assert doc["questions"] == 1
    assert month["searches"] == 2
    assert user_month["firebaseUid"] == "test_uid"
    assert "expiresAt" in user_day and "expiresAt" in day
    assert "expiresAt" not in month


async def test_cost_is_recorded_when_the_answer_fails(api_client, mock_db, monkeypatch) -> None:
    from src.api import chat as chat_api

    async def _fails(**kwargs):  # noqa: ANN003, ANN202
        kwargs["meter"].add_model_cost(0.05)
        raise APIError(502, "AI_ERROR", "boom")
        yield {}  # pragma: no cover

    monkeypatch.setattr(chat_api, "generate_response_events", _fails)

    response = await _ask(api_client)

    assert "event: error" in response.text
    month = await _doc(mock_db, f"service:month:{_this_month()}")
    assert month is not None and month["costUsd"] == pytest.approx(0.05)


async def test_account_deletion_removes_usage_counters_but_keeps_service_totals(
    api_client, mock_db, auth_headers
) -> None:
    await _seed(mock_db, f"user:test_uid:month:{_MONTH}", firebaseUid="test_uid", costUsd=1.0)
    await _seed(mock_db, f"user:test_uid:day:{_DAY}", firebaseUid="test_uid", questions=3)
    await _seed(mock_db, f"service:month:{_MONTH}", costUsd=4.0)

    response = await api_client.request(
        "DELETE", "/api/account", headers=auth_headers, json={"confirmation": "DELETE"}
    )

    assert response.status_code == 200
    assert await mock_db.usageCounters.count_documents({"firebaseUid": "test_uid"}) == 0
    assert await mock_db.usageCounters.find_one({"_id": f"service:month:{_MONTH}"}) is not None


# --- Budget reservations -----------------------------------------------------------


async def test_parallel_answers_cannot_overrun_the_monthly_budget(mock_db, monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "question_cost_reserve_usd", 0.7)
    await _seed(mock_db, f"service:month:{_MONTH}", costUsd=9.0)

    first = await admit_question(mock_db, "uid_1", None, now=_NOW)
    with pytest.raises(APIError) as refused:
        await admit_question(mock_db, "uid_2", None, now=_NOW)
    assert refused.value.code == "SERVICE_LIMIT"

    first.release()
    second = await admit_question(mock_db, "uid_2", None, now=_NOW)
    second.release()


async def test_forgotten_reservation_expires(mock_db, monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "question_cost_reserve_usd", 0.7)
    await _seed(mock_db, f"service:month:{_MONTH}", costUsd=9.0)
    clock = [1000.0]
    monkeypatch.setattr(usage_limits, "_monotonic", lambda: clock[0])

    await admit_question(mock_db, "uid_1", None, now=_NOW)  # never released
    clock[0] += 16 * 60

    later = await admit_question(mock_db, "uid_2", None, now=_NOW)
    later.release()


async def test_record_usage_adds_to_existing_totals(mock_db) -> None:
    await record_usage(mock_db, "uid_1", 0.10, searches=1, now=_NOW)
    await record_usage(mock_db, "uid_1", 0.05, now=_NOW)

    month = await mock_db.usageCounters.find_one({"_id": f"service:month:{_MONTH}"})
    assert month["costUsd"] == pytest.approx(0.15)
    assert month["searches"] == 1


async def test_service_has_budget_counts_answers_in_progress(mock_db, monkeypatch) -> None:
    monkeypatch.setattr(get_settings(), "question_cost_reserve_usd", 0.5)
    await _seed(mock_db, f"service:month:{_MONTH}", costUsd=9.4)

    assert await usage_limits.service_has_budget(mock_db, 0.2, now=_NOW)
    held = await admit_question(mock_db, "uid_1", None, now=_NOW)
    assert not await usage_limits.service_has_budget(mock_db, 0.2, now=_NOW)
    held.release()
    assert await usage_limits.service_has_budget(mock_db, 0.2, now=_NOW)


def test_meter_prices_searches_by_depth() -> None:
    meter = UsageMeter(search_cost_usd=0.016)
    meter.add_model_cost(0.1)
    meter.add_searches(3)

    assert meter.total_usd == pytest.approx(0.148)
    advanced = usage_limits.new_meter(get_settings())
    assert advanced.search_cost_usd == pytest.approx(0.016)
