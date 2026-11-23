from __future__ import annotations

import json

from src.api import chat as chat_api
from src.services.profile_service import upsert_v10_digest

_SOURCE_A = {"title": "A", "url": "https://a.example/", "source": "a.example", "content": "a"}
_SOURCE_B = {"title": "B", "url": "https://b.example/", "source": "b.example", "content": "b"}
_NO_EMERGENCY = 'SAFETY_SIGNAL: {"requiresEmergencyCare": false, "category": "none"}'


def _fake_generator(tokens: list[str], results: list[dict]):  # noqa: ANN202
    async def _generate(question, conversation_history, v10_digest, sources, answer_format=None):  # noqa: ANN001, ANN202
        sources.register(results)
        yield {"type": "tool_use", "tool": "tavily_search", "status": "searching", "query": "q"}
        for token in tokens:
            yield {"type": "token", "text": token}

    return _generate


async def _ask(api_client, auth_headers, question: str) -> list[tuple[str, dict]]:  # noqa: ANN001
    response = await api_client.post(
        "/api/chat/ask", json={"question": question}, headers=auth_headers
    )
    assert response.status_code == 200
    events = []
    for block in response.text.strip().split("\n\n"):
        lines = dict(line.split(": ", 1) for line in block.splitlines())
        events.append((lines["event"], json.loads(lines["data"])))
    return events


def _done(events: list[tuple[str, dict]]) -> dict:
    return next(data for name, data in events if name == "done")


async def test_done_citations_come_from_registry(monkeypatch, api_client, auth_headers):
    monkeypatch.setattr(
        chat_api,
        "generate_response_events",
        _fake_generator(["Use rest [2] and fluids [1].\n", _NO_EMERGENCY], [_SOURCE_A, _SOURCE_B]),
    )

    done = _done(await _ask(api_client, auth_headers, "How do I treat a cold?"))

    assert done["content"] == "Use rest [1] and fluids [2]."
    assert [c["url"] for c in done["citations"]] == ["https://b.example/", "https://a.example/"]
    assert [c["number"] for c in done["citations"]] == [1, 2]


async def test_signal_line_never_streamed(monkeypatch, api_client, auth_headers):
    monkeypatch.setattr(
        chat_api,
        "generate_response_events",
        _fake_generator(["Use rest [2].\nSAFE", _NO_EMERGENCY[4:]], [_SOURCE_A]),
    )

    events = await _ask(api_client, auth_headers, "How do I treat a cold?")

    streamed = "".join(data["text"] for name, data in events if name == "token")
    assert "SAFETY_SIGNAL" not in streamed
    assert streamed == "Use rest [2].\n"


async def test_self_harm_answer_gets_international_crisis_resources(
    monkeypatch, api_client, auth_headers
):
    signal = 'SAFETY_SIGNAL: {"requiresEmergencyCare": true, "category": "self_harm"}'
    monkeypatch.setattr(
        chat_api,
        "generate_response_events",
        _fake_generator(["I'm really sorry you're feeling this way.\n", signal], []),
    )

    done = _done(await _ask(api_client, auth_headers, "I feel hopeless"))

    assert done["requiresEmergencyCare"] is True
    assert "https://findahelpline.com" in done["content"]
    assert "112" in done["content"]


async def test_no_signal_and_emergency_question_sets_flag(monkeypatch, api_client, auth_headers):
    monkeypatch.setattr(
        chat_api, "generate_response_events", _fake_generator(["Please get help now."], [])
    )

    done = _done(await _ask(api_client, auth_headers, "I have crushing chest pain right now"))

    assert done["requiresEmergencyCare"] is True


async def test_placeholder_profile_is_not_sent_to_the_model(
    monkeypatch, api_client, auth_headers, mock_db
):
    await upsert_v10_digest(mock_db, "test_uid", "(No health profile set up yet)")
    seen: dict = {}

    async def _generate(question, conversation_history, v10_digest, sources, answer_format=None):  # noqa: ANN001, ANN202
        seen["v10_digest"] = v10_digest
        yield {"type": "token", "text": "Hello."}

    monkeypatch.setattr(chat_api, "generate_response_events", _generate)

    await _ask(api_client, auth_headers, "Hi")

    assert seen["v10_digest"] is None


async def test_self_harm_words_get_crisis_resources_even_if_model_says_no_emergency(
    monkeypatch, api_client, auth_headers
):
    monkeypatch.setattr(
        chat_api,
        "generate_response_events",
        _fake_generator(["Here is some general advice.\n", _NO_EMERGENCY], []),
    )

    done = _done(
        await _ask(api_client, auth_headers, "Sometimes I feel like I don't want to live anymore")
    )

    assert "https://findahelpline.com" in done["content"]
    assert done["requiresEmergencyCare"] is False


def _recording_generator(seen: dict):  # noqa: ANN202
    async def _generate(question, conversation_history, v10_digest, sources, answer_format=None):  # noqa: ANN001, ANN202
        seen["answer_format"] = answer_format
        yield {"type": "token", "text": "Rest helps.\n" + _NO_EMERGENCY}

    return _generate


async def test_answer_format_reaches_the_generator(monkeypatch, api_client, auth_headers):
    seen: dict = {}
    monkeypatch.setattr(chat_api, "generate_response_events", _recording_generator(seen))

    response = await api_client.post(
        "/api/chat/ask",
        json={"question": "Is coffee okay with metformin?", "answerFormat": "sections"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert seen["answer_format"] == "sections"


async def test_requests_without_answer_format_keep_the_old_layout(
    monkeypatch, api_client, auth_headers
):
    seen: dict = {}
    monkeypatch.setattr(chat_api, "generate_response_events", _recording_generator(seen))

    response = await api_client.post(
        "/api/chat/ask", json={"question": "Is coffee okay?"}, headers=auth_headers
    )

    assert response.status_code == 200
    assert seen["answer_format"] is None


async def test_unknown_answer_format_falls_back_to_the_default_layout(
    monkeypatch, api_client, auth_headers
):
    # A newer app may ask for a layout this server doesn't know yet; it still gets an answer.
    seen: dict = {}
    monkeypatch.setattr(chat_api, "generate_response_events", _recording_generator(seen))

    response = await api_client.post(
        "/api/chat/ask",
        json={"question": "Is coffee okay?", "answerFormat": "cards-v2"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert seen["answer_format"] is None
