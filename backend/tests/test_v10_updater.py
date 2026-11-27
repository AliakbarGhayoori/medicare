from __future__ import annotations

import logging
from types import SimpleNamespace

import pytest

from src.ai import v10_updater
from src.services.profile_service import get_v10_digest, upsert_v10_digest
from src.utils import utcnow

_PLACEHOLDER = "(No health profile set up yet)"
_QUESTION = "I take agomelatine 12.5 mg and I'm tapering off it over 4 weeks"
_UID = "uid_v10"


class _FakeCompletions:
    def __init__(self, reply: str | Exception, finish_reason: str, cost: float | None) -> None:
        self._reply = reply
        self._finish_reason = finish_reason
        self._cost = cost
        self.requests: list[dict] = []

    async def create(self, **kwargs):  # noqa: ANN003, ANN204
        self.requests.append(kwargs)
        if isinstance(self._reply, Exception):
            raise self._reply
        message = SimpleNamespace(content=self._reply)
        return SimpleNamespace(
            choices=[SimpleNamespace(message=message, finish_reason=self._finish_reason)],
            usage=SimpleNamespace(cost=self._cost) if self._cost is not None else None,
        )


@pytest.fixture
def ai_settings():  # noqa: ANN201
    return SimpleNamespace(
        mock_ai=False,
        openrouter_api_key="test-key",
        anthropic_api_key="",
        ai_model="test-model",
        ai_fallback_models=[],
        ai_reasoning_effort=None,
    )


def _install(monkeypatch, ai_settings, reply, finish_reason="stop", cost=None) -> _FakeCompletions:  # noqa: ANN001
    completions = _FakeCompletions(reply, finish_reason, cost)
    client = SimpleNamespace(chat=SimpleNamespace(completions=completions))
    monkeypatch.setattr(v10_updater, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(v10_updater, "get_openai_client", lambda: client)
    return completions


async def _update(mock_db, question: str = _QUESTION) -> bool:  # noqa: ANN001
    return await v10_updater.update_v10_after_conversation(
        db=mock_db,
        firebase_uid=_UID,
        user_question=question,
        assistant_response="Tapering slowly is sensible [1].",
    )


async def _stored_digest(mock_db) -> str | None:  # noqa: ANN001
    doc = await get_v10_digest(mock_db, _UID)
    return doc.get("digest") if doc else None


def _sent_text(completions: _FakeCompletions) -> str:
    return "\n".join(m["content"] for m in completions.requests[0]["messages"])


async def test_stated_medicine_is_saved(monkeypatch, ai_settings, mock_db):
    profile = "Medications:\n- Agomelatine 12.5 mg, tapering for 4 weeks"
    _install(monkeypatch, ai_settings, profile)

    assert await _update(mock_db) is True

    doc = await get_v10_digest(mock_db, _UID)
    assert doc["digest"] == profile
    assert doc["lastUpdateSource"] == "auto"


@pytest.mark.parametrize(
    "reply",
    [
        "NO_CHANGE",
        " NO_CHANGE\n",
        "`NO_CHANGE`",
        "NO_CHANGE.",
        "NO_CHANGE\n\nThe user did not state anything new.",
        "NO_CHANGE - nothing new was stated",
        "No change.",
        "NO CHANGE",
        "**No changes**",
    ],
)
async def test_no_change_reply_is_not_saved(monkeypatch, ai_settings, mock_db, reply):
    await upsert_v10_digest(mock_db, _UID, "Conditions: Asthma")
    _install(monkeypatch, ai_settings, reply)

    assert await _update(mock_db) is False

    doc = await get_v10_digest(mock_db, _UID)
    assert (doc["digest"], doc["version"]) == ("Conditions: Asthma", 1)


async def test_placeholder_reply_is_never_saved(monkeypatch, ai_settings, mock_db):
    _install(monkeypatch, ai_settings, _PLACEHOLDER)

    assert await _update(mock_db) is False
    assert await _stored_digest(mock_db) is None


async def test_truncated_reply_is_never_saved(monkeypatch, ai_settings, mock_db):
    await upsert_v10_digest(mock_db, _UID, "Conditions: Asthma\nMedications: Salbutamol")
    _install(monkeypatch, ai_settings, "Conditions: Asthma\nMedica", finish_reason="length")

    assert await _update(mock_db) is False
    assert await _stored_digest(mock_db) == "Conditions: Asthma\nMedications: Salbutamol"


async def test_ai_failure_does_not_save_raw_question(monkeypatch, ai_settings, mock_db):
    _install(monkeypatch, ai_settings, RuntimeError("provider down"))

    assert await _update(mock_db) is False
    assert await _stored_digest(mock_db) is None


async def test_updater_prompt_never_contains_placeholder(monkeypatch, ai_settings, mock_db):
    await upsert_v10_digest(mock_db, _UID, _PLACEHOLDER)
    completions = _install(monkeypatch, ai_settings, "NO_CHANGE")

    await _update(mock_db)

    sent = _sent_text(completions)
    assert _PLACEHOLDER not in sent
    assert _QUESTION in sent


async def test_updater_prompt_sends_profile_verbatim_with_extraction_rules(
    monkeypatch, ai_settings, mock_db
):
    await upsert_v10_digest(mock_db, _UID, "Medicin: Metformin 500 mg to gange dagligt")
    completions = _install(monkeypatch, ai_settings, "NO_CHANGE")

    await _update(mock_db)

    sent = _sent_text(completions)
    assert "Medicin: Metformin 500 mg to gange dagligt" in sent
    assert "NO_CHANGE" in sent
    assert "Agomelatine 12.5 mg, tapering for 4 weeks" in sent
    assert "any language" in sent


async def test_updater_logs_contain_no_question_text(monkeypatch, ai_settings, mock_db, caplog):
    caplog.set_level(logging.DEBUG)
    _install(monkeypatch, ai_settings, "Medications: Agomelatine 12.5 mg")
    await _update(mock_db)
    _install(monkeypatch, ai_settings, RuntimeError(f"bad request: {_QUESTION}"))
    await _update(mock_db, question="I also take agomelatine at night")

    assert "agomelatine" not in caplog.text.lower()


async def test_without_ai_the_heuristic_records_the_concern(monkeypatch, ai_settings, mock_db):
    ai_settings.mock_ai = True
    completions = _install(monkeypatch, ai_settings, "unused")

    assert await _update(mock_db) is True

    assert _QUESTION in (await _stored_digest(mock_db) or "")
    assert completions.requests == []


# --- Cost ----------------------------------------------------------------------


async def test_profile_update_cost_is_recorded(monkeypatch, ai_settings, mock_db):
    _install(monkeypatch, ai_settings, "Medicines: agomelatine 12.5 mg (tapering)", cost=0.004)

    await _update(mock_db)

    month = utcnow().strftime("%Y-%m")
    service = await mock_db.usageCounters.find_one({"_id": f"service:month:{month}"})
    user = await mock_db.usageCounters.find_one({"_id": f"user:{_UID}:month:{month}"})
    assert service["costUsd"] == pytest.approx(0.004)
    assert user["costUsd"] == pytest.approx(0.004)


async def test_profile_update_waits_when_the_budget_is_spent(monkeypatch, ai_settings, mock_db):
    month = utcnow().strftime("%Y-%m")
    await mock_db.usageCounters.insert_one({"_id": f"service:month:{month}", "costUsd": 10.0})
    completions = _install(monkeypatch, ai_settings, "Medicines: agomelatine 12.5 mg")

    assert await _update(mock_db) is False
    assert completions.requests == []
