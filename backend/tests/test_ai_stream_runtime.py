from __future__ import annotations

import json
from types import SimpleNamespace

import pytest

from src.ai import stream as stream_runtime
from src.exceptions import APIError


class _FakeAPIError(Exception):
    def __init__(self, status_code: int, headers: dict[str, str] | None = None) -> None:
        super().__init__(f"status={status_code}")
        self.status_code = status_code
        self.response = SimpleNamespace(status_code=status_code, headers=headers or {})


def _tool_use_response(query: str, tool_use_id: str = "call_1") -> SimpleNamespace:
    """Fake an OpenAI chat completion with a tool call."""
    tool_call = SimpleNamespace(
        id=tool_use_id,
        type="function",
        function=SimpleNamespace(
            name="tavily_search",
            arguments=json.dumps({"query": query}),
        ),
    )
    message = SimpleNamespace(
        role="assistant",
        content=None,
        tool_calls=[tool_call],
    )
    message.model_dump = lambda: {
        "role": "assistant",
        "content": None,
        "tool_calls": [
            {
                "id": tool_use_id,
                "type": "function",
                "function": {
                    "name": "tavily_search",
                    "arguments": json.dumps({"query": query}),
                },
            }
        ],
    }
    choice = SimpleNamespace(message=message, finish_reason="tool_calls", index=0)
    return SimpleNamespace(choices=[choice])


def _text_response(text: str) -> SimpleNamespace:
    """Fake an OpenAI chat completion with a text response."""
    message = SimpleNamespace(
        role="assistant",
        content=text,
        tool_calls=None,
    )
    message.model_dump = lambda: {
        "role": "assistant",
        "content": text,
        "tool_calls": None,
    }
    choice = SimpleNamespace(message=message, finish_reason="stop", index=0)
    return SimpleNamespace(choices=[choice])


class _FakeCompletions:
    def __init__(self, create_responses: list[object]) -> None:
        self._create_responses = list(create_responses)
        self.create_calls = 0
        self.create_requests: list[dict] = []

    async def create(self, **kwargs):  # noqa: ANN003
        self.create_calls += 1
        self.create_requests.append(kwargs)
        if not self._create_responses:
            return _text_response("")
        next_response = self._create_responses.pop(0)
        if isinstance(next_response, Exception):
            raise next_response
        return next_response


class _FakeChat:
    def __init__(self, completions: _FakeCompletions) -> None:
        self.completions = completions


class _FakeClient:
    def __init__(self, completions: _FakeCompletions) -> None:
        self.chat = _FakeChat(completions)


@pytest.fixture
def ai_settings():
    return SimpleNamespace(
        mock_ai=False,
        ai_provider="openrouter",
        openrouter_api_key="test-key",
        anthropic_api_key="",
        anthropic_model="test-model",
        anthropic_max_tokens=256,
        ai_temperature=0.1,
        max_conversation_context_messages=10,
        sse_chunk_size=20,
        ai_tool_min_calls=1,
        ai_tool_max_rounds=4,
        ai_tool_max_calls=8,
    )


async def _collect_events() -> list[dict]:
    events: list[dict] = []
    async for event in stream_runtime.generate_response_events(
        question="How should I manage dizziness?",
        conversation_history=[],
        v10_digest=None,
    ):
        events.append(event)
    return events


async def test_model_can_make_tool_calls_and_then_return_text(monkeypatch, ai_settings):
    fake_completions = _FakeCompletions(
        create_responses=[
            _tool_use_response("dizziness older adults causes red flags"),
            _text_response(
                "Final answer with evidence [1].\n\nSources:\n[1] Example (https://a.org)\n"
            ),
        ]
    )
    fake_client = _FakeClient(fake_completions)
    tool_queries: list[str] = []

    async def _fake_tavily_search(**kwargs):  # noqa: ANN003
        tool_queries.append(kwargs["query"])
        return {
            "query": kwargs["query"],
            "answer": "",
            "results": [
                {
                    "title": "Mayo Clinic",
                    "url": "https://www.mayoclinic.org/example",
                    "source": "mayoclinic.org",
                    "content": "Example snippet",
                    "favicon": "",
                    "score": 0.9,
                }
            ],
        }

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: fake_client)
    monkeypatch.setattr(stream_runtime, "execute_tavily_search", _fake_tavily_search)

    events = await _collect_events()
    token_text = "".join(event.get("text", "") for event in events if event.get("type") == "token")

    assert any(event.get("type") == "tool_use" for event in events)
    assert tool_queries == ["dizziness older adults causes red flags"]
    assert "Final answer with evidence" in token_text
    assert fake_completions.create_calls == 2

    second_request = fake_completions.create_requests[1]
    tool_msg = second_request["messages"][-1]
    assert tool_msg["role"] == "tool"


async def test_model_responds_without_tool_calls(monkeypatch, ai_settings):
    """Model can respond directly without searching (e.g. greetings)."""
    fake_completions = _FakeCompletions(
        create_responses=[
            _text_response("Hello! How can I help you today?"),
        ]
    )
    fake_client = _FakeClient(fake_completions)

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: fake_client)

    events = await _collect_events()
    token_text = "".join(event.get("text", "") for event in events if event.get("type") == "token")

    assert "Hello" in token_text


async def test_create_retries_on_retryable_server_errors(monkeypatch, ai_settings):
    fake_completions = _FakeCompletions(
        create_responses=[
            _FakeAPIError(status_code=503),
            _text_response("Recovered response."),
        ]
    )
    fake_client = _FakeClient(fake_completions)

    async def _no_sleep(_: float) -> None:
        return None

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: fake_client)
    monkeypatch.setattr(stream_runtime.asyncio, "sleep", _no_sleep)

    events = await _collect_events()
    token_text = "".join(event.get("text", "") for event in events if event.get("type") == "token")

    assert "Recovered response." in token_text
    assert fake_completions.create_calls == 2


async def test_create_rate_limit_maps_retry_after_header(monkeypatch, ai_settings):
    class _FakeRateLimitError(Exception):
        def __init__(self) -> None:
            super().__init__("429")
            self.response = SimpleNamespace(status_code=429, headers={"Retry-After": "17"})

    fake_completions = _FakeCompletions(create_responses=[_FakeRateLimitError()])
    fake_client = _FakeClient(fake_completions)

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: fake_client)
    monkeypatch.setattr(stream_runtime.openai, "RateLimitError", _FakeRateLimitError)

    with pytest.raises(APIError) as exc_info:
        await _collect_events()

    assert exc_info.value.code == "RATE_LIMITED"
    assert exc_info.value.headers.get("Retry-After") == "17"


async def test_fails_when_model_exceeds_tool_call_limit(monkeypatch, ai_settings):
    ai_settings.ai_tool_max_calls = 1
    fake_completions = _FakeCompletions(
        create_responses=[
            _tool_use_response("first query", tool_use_id="call_1"),
            _tool_use_response("second query", tool_use_id="call_2"),
        ]
    )
    fake_client = _FakeClient(fake_completions)

    async def _fake_tavily_search(**kwargs):  # noqa: ANN003
        return {"query": kwargs["query"], "answer": "", "results": []}

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: fake_client)
    monkeypatch.setattr(stream_runtime, "execute_tavily_search", _fake_tavily_search)

    with pytest.raises(APIError) as exc_info:
        await _collect_events()

    assert exc_info.value.code == "AI_ERROR"


async def test_openrouter_key_enables_live_path(monkeypatch, ai_settings):
    ai_settings.openrouter_api_key = "or-live-key"
    ai_settings.anthropic_api_key = ""

    fake_completions = _FakeCompletions(
        create_responses=[_text_response("Live OpenRouter response.")]
    )
    fake_client = _FakeClient(fake_completions)

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: fake_client)

    events = await _collect_events()
    token_text = "".join(event.get("text", "") for event in events if event.get("type") == "token")

    assert "Live OpenRouter response." in token_text
    assert fake_completions.create_calls == 1


async def test_openrouter_without_keys_falls_back_to_mock(monkeypatch, ai_settings):
    ai_settings.openrouter_api_key = ""
    ai_settings.anthropic_api_key = ""

    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)

    events = await _collect_events()
    token_text = "".join(event.get("text", "") for event in events if event.get("type") == "token")

    assert any(event.get("type") == "tool_use" for event in events)
    assert "What to do next" in token_text
