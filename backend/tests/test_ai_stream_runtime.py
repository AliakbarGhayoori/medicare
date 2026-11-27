from __future__ import annotations

import json
import logging
from types import SimpleNamespace

import pytest

from src.ai import stream as stream_runtime
from src.ai.sources import SourceRegistry
from src.exceptions import APIError
from src.services.usage_limits import UsageMeter

# --- Fakes mirroring OpenAI/OpenRouter streaming chunks -----------------------


class _FakeAPIError(Exception):
    def __init__(self, status_code: int, headers: dict[str, str] | None = None) -> None:
        super().__init__(f"status={status_code}")
        self.status_code = status_code
        self.response = SimpleNamespace(status_code=status_code, headers=headers or {})


def _chunk(*, content=None, tool_calls=None, reasoning=None, finish_reason=None, model=None):  # noqa: ANN001, ANN202
    delta = SimpleNamespace(
        content=content,
        tool_calls=tool_calls,
        model_extra={"reasoning_details": reasoning} if reasoning else {},
    )
    chunk = SimpleNamespace(choices=[SimpleNamespace(delta=delta, finish_reason=finish_reason)])
    if model:
        chunk.model = model
    return chunk


def _tool_delta(index: int, *, call_id=None, name=None, arguments=None):  # noqa: ANN001, ANN202
    return SimpleNamespace(
        index=index,
        id=call_id,
        type="function" if call_id else None,
        function=SimpleNamespace(name=name, arguments=arguments),
    )


def text_round(*pieces: str) -> list:
    return [_chunk(content=piece) for piece in pieces] + [_chunk(finish_reason="stop")]


def tool_round(queries: list[str], *, reasoning=None, preamble=None) -> list:  # noqa: ANN001
    chunks = [_chunk(content=preamble)] if preamble else []
    for index, query in enumerate(queries):
        arguments = json.dumps({"query": query})
        half = len(arguments) // 2
        chunks.append(
            _chunk(
                tool_calls=[
                    _tool_delta(
                        index,
                        call_id=f"call_{index}",
                        name="tavily_search",
                        arguments=arguments[:half],
                    )
                ]
            )
        )
        chunks.append(_chunk(tool_calls=[_tool_delta(index, arguments=arguments[half:])]))
    for item in reasoning or []:
        chunks.append(_chunk(reasoning=[item]))
    chunks.append(_chunk(finish_reason="tool_calls"))
    return chunks


class _FakeStream:
    def __init__(self, chunks: list) -> None:
        self._chunks = chunks

    def __aiter__(self):  # noqa: ANN204
        return self._iterate()

    async def _iterate(self):  # noqa: ANN202
        for chunk in self._chunks:
            if isinstance(chunk, Exception):
                raise chunk  # the connection broke mid-answer
            yield chunk


class _FakeCompletions:
    def __init__(self, rounds: list) -> None:
        self._rounds = list(rounds)
        self.requests: list[dict] = []

    async def create(self, **kwargs):  # noqa: ANN003, ANN204
        assert kwargs.get("stream") is True
        self.requests.append({**kwargs, "messages": [dict(m) for m in kwargs["messages"]]})
        next_round = self._rounds.pop(0) if self._rounds else text_round()
        if isinstance(next_round, Exception):
            raise next_round
        return _FakeStream(next_round)


@pytest.fixture
def ai_settings():  # noqa: ANN201
    return SimpleNamespace(
        mock_ai=False,
        ai_provider="openrouter",
        openrouter_api_key="test-key",
        anthropic_api_key="",
        ai_model="test-model",
        ai_fallback_models=[],
        ai_reasoning_effort=None,
        ai_max_tokens=256,
        ai_temperature=0.1,
        max_conversation_context_messages=10,
        sse_chunk_size=20,
        ai_tool_min_calls=1,
        ai_tool_max_rounds=4,
        ai_tool_max_calls=8,
    )


@pytest.fixture
def searches(monkeypatch):  # noqa: ANN001, ANN201
    queries: list[str] = []

    async def _fake_search(**kwargs):  # noqa: ANN003, ANN202
        query = kwargs["query"]
        queries.append(query)
        return {
            "query": query,
            "answer": "",
            "results": [
                {
                    "title": f"About {query}",
                    "url": f"https://source.example/{query.replace(' ', '-')}",
                    "source": "source.example",
                    "content": f"Evidence about {query}",
                }
            ],
        }

    monkeypatch.setattr(stream_runtime, "execute_tavily_search", _fake_search)
    return queries


def _install(monkeypatch, ai_settings, rounds: list) -> _FakeCompletions:  # noqa: ANN001
    completions = _FakeCompletions(rounds)
    client = SimpleNamespace(chat=SimpleNamespace(completions=completions))
    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)
    monkeypatch.setattr(stream_runtime, "get_openai_client", lambda: client)
    return completions


async def _run(
    question: str = "How should I manage dizziness?",
) -> tuple[list[dict], SourceRegistry]:
    sources = SourceRegistry()
    events = [
        event
        async for event in stream_runtime.generate_response_events(
            question=question, conversation_history=[], v10_digest=None, sources=sources
        )
    ]
    return events, sources


def _tokens(events: list[dict]) -> list[str]:
    return [event["text"] for event in events if event["type"] == "token"]


def _tool_payloads(request: dict) -> list[dict]:
    return [json.loads(m["content"]) for m in request["messages"] if m["role"] == "tool"]


async def _no_sleep(_: float) -> None:
    return None


# --- Research policy -----------------------------------------------------------


async def test_health_question_forces_search_on_first_round(monkeypatch, ai_settings, searches):
    completions = _install(
        monkeypatch, ai_settings, [tool_round(["dizziness causes"]), text_round("Answer [1].")]
    )

    events, _ = await _run()

    assert completions.requests[0]["tool_choice"] == "required"
    assert "".join(_tokens(events)) == "Answer [1]."


async def test_small_talk_does_not_force_search(monkeypatch, ai_settings, searches):
    completions = _install(monkeypatch, ai_settings, [text_round("You're welcome!")])

    await _run(question="thanks!")

    assert completions.requests[0]["tool_choice"] == "auto"
    assert searches == []


async def test_min_calls_forces_another_research_round(monkeypatch, ai_settings, searches):
    ai_settings.ai_tool_min_calls = 2
    completions = _install(
        monkeypatch,
        ai_settings,
        [tool_round(["a"]), tool_round(["b"]), text_round("Done [1][2].")],
    )

    await _run()

    assert [r.get("tool_choice") for r in completions.requests] == ["required", "required", "auto"]


# --- Streaming and pass-back ---------------------------------------------------


async def test_answer_tokens_stream_in_model_order(monkeypatch, ai_settings, searches):
    _install(monkeypatch, ai_settings, [tool_round(["q"]), text_round("Hel", "lo [1]")])

    events, _ = await _run()

    assert _tokens(events) == ["Hel", "lo [1]"]


async def test_search_events_announce_each_query(monkeypatch, ai_settings, searches):
    _install(monkeypatch, ai_settings, [tool_round(["a", "b"]), text_round("Done.")])

    events, _ = await _run()

    tool_events = [(e["status"], e["query"]) for e in events if e["type"] == "tool_use"]
    assert tool_events == [("planning", None), ("searching", "a"), ("searching", "b")]


async def test_reasoning_details_and_tool_calls_are_passed_back(monkeypatch, ai_settings, searches):
    signature = {
        "type": "reasoning.encrypted",
        "data": "sig",
        "format": "google-gemini-v1",
        "id": "call_0",
        "index": 0,
    }
    completions = _install(
        monkeypatch,
        ai_settings,
        [tool_round(["dizziness causes"], reasoning=[signature]), text_round("Answer [1].")],
    )

    await _run()

    assistant = next(m for m in completions.requests[1]["messages"] if m["role"] == "assistant")
    assert assistant["reasoning_details"] == [signature]
    assert assistant["tool_calls"][0]["id"] == "call_0"
    assert assistant["tool_calls"][0]["function"] == {
        "name": "tavily_search",
        "arguments": json.dumps({"query": "dizziness causes"}),
    }


async def test_split_reasoning_items_are_merged(monkeypatch, ai_settings, searches):
    pieces = [
        {"type": "reasoning.text", "text": "Thinking ", "index": 0},
        {"type": "reasoning.text", "text": "it over", "index": 0},
    ]
    completions = _install(
        monkeypatch, ai_settings, [tool_round(["q"], reasoning=pieces), text_round("Done.")]
    )

    await _run()

    assistant = next(m for m in completions.requests[1]["messages"] if m["role"] == "assistant")
    assert assistant["reasoning_details"] == [
        {"type": "reasoning.text", "text": "Thinking it over", "index": 0}
    ]


async def test_preamble_and_answer_both_stream(monkeypatch, ai_settings, searches):
    completions = _install(
        monkeypatch,
        ai_settings,
        [tool_round(["a"], preamble="Let me check. "), text_round("Answer [1].")],
    )

    events, _ = await _run()

    assert "".join(_tokens(events)) == "Let me check. Answer [1]."
    assistant = next(m for m in completions.requests[1]["messages"] if m["role"] == "assistant")
    assert assistant["content"] == "Let me check. "


async def test_fallback_routing_is_sent_with_every_round(monkeypatch, ai_settings, searches):
    ai_settings.ai_fallback_models = ["openai/gpt-5.4"]
    completions = _install(monkeypatch, ai_settings, [tool_round(["a"]), text_round("Done.")])

    await _run()

    for request in completions.requests:
        assert request["model"] == "test-model"
        assert request["extra_body"]["models"] == ["test-model", "openai/gpt-5.4"]
        assert request["extra_body"]["usage"] == {"include": True}


# --- Search results and budgets ------------------------------------------------


async def test_tool_results_use_registry_numbers(monkeypatch, ai_settings, searches):
    completions = _install(monkeypatch, ai_settings, [tool_round(["a", "b"]), text_round("Done.")])

    _, sources = await _run()

    payloads = _tool_payloads(completions.requests[1])
    assert [payload["ok"] for payload in payloads] == [True, True]
    assert [result["n"] for payload in payloads for result in payload["results"]] == [1, 2]
    assert len(sources) == 2


async def test_spent_budget_forces_final_round_without_tools(monkeypatch, ai_settings, searches):
    ai_settings.ai_tool_max_calls = 2
    completions = _install(
        monkeypatch, ai_settings, [tool_round(["a", "b", "c"]), text_round("Done.")]
    )

    await _run()

    assert searches == ["a", "b"]
    assert _tool_payloads(completions.requests[1])[2]["error"]["code"] == "SEARCH_BUDGET_EXHAUSTED"
    assert "tools" not in completions.requests[1]
    assert "tool_choice" not in completions.requests[1]


async def test_last_round_omits_tools(monkeypatch, ai_settings, searches):
    ai_settings.ai_tool_max_rounds = 2
    completions = _install(monkeypatch, ai_settings, [tool_round(["a"]), text_round("Done.")])

    await _run()

    assert "tools" in completions.requests[0]
    assert "tools" not in completions.requests[1]


async def test_one_failed_search_does_not_block_answer(monkeypatch, ai_settings):
    async def _search(**kwargs):  # noqa: ANN003, ANN202
        if kwargs["query"] == "bad":
            raise APIError(502, "SEARCH_BACKEND_ERROR", "Tavily search failed.")
        return {
            "query": kwargs["query"],
            "answer": "",
            "results": [{"title": "T", "url": "https://ok.example/", "source": "ok.example"}],
        }

    monkeypatch.setattr(stream_runtime, "execute_tavily_search", _search)
    completions = _install(
        monkeypatch, ai_settings, [tool_round(["good", "bad"]), text_round("Answer [1].")]
    )

    events, sources = await _run()

    assert "".join(_tokens(events)) == "Answer [1]."
    assert len(sources) == 1
    assert [payload["ok"] for payload in _tool_payloads(completions.requests[1])] == [True, False]


# --- Failures --------------------------------------------------------------------


async def test_empty_answer_raises_ai_error(monkeypatch, ai_settings, searches):
    _install(monkeypatch, ai_settings, [tool_round(["a"]), text_round()])

    with pytest.raises(APIError) as exc_info:
        await _run()

    assert exc_info.value.code == "AI_ERROR"


async def test_create_retries_on_retryable_server_errors(monkeypatch, ai_settings, searches):
    completions = _install(
        monkeypatch, ai_settings, [_FakeAPIError(status_code=503), text_round("Recovered.")]
    )
    monkeypatch.setattr(stream_runtime.asyncio, "sleep", _no_sleep)

    events, _ = await _run(question="thanks")

    assert "".join(_tokens(events)) == "Recovered."
    assert len(completions.requests) == 2


async def test_create_rate_limit_maps_retry_after_header(monkeypatch, ai_settings, searches):
    class _FakeRateLimitError(Exception):
        def __init__(self) -> None:
            super().__init__("429")
            self.response = SimpleNamespace(status_code=429, headers={"Retry-After": "17"})

    _install(monkeypatch, ai_settings, [_FakeRateLimitError()])
    monkeypatch.setattr(stream_runtime.openai, "RateLimitError", _FakeRateLimitError)

    with pytest.raises(APIError) as exc_info:
        await _run()

    assert exc_info.value.code == "RATE_LIMITED"
    assert exc_info.value.headers.get("Retry-After") == "17"


# --- Privacy and mock mode ---------------------------------------------------------


async def test_search_queries_never_logged(monkeypatch, ai_settings, searches, caplog):
    caplog.set_level(logging.DEBUG)
    _install(monkeypatch, ai_settings, [tool_round(["zebra-knee-ache-7731"]), text_round("A [1].")])

    await _run()

    assert "zebra-knee-ache-7731" not in caplog.text
    assert all("zebra-knee-ache-7731" not in str(record.__dict__) for record in caplog.records)


async def test_preamble_without_trailing_space_is_separated_from_answer(
    monkeypatch, ai_settings, searches
):
    _install(
        monkeypatch,
        ai_settings,
        [tool_round(["dizziness"], preamble="Let me look that up."), text_round("Rest helps [1].")],
    )

    events, _ = await _run()

    assert "".join(_tokens(events)) == "Let me look that up.\n\nRest helps [1]."


async def test_round_logs_name_the_serving_model(monkeypatch, ai_settings, searches, caplog):
    caplog.set_level(logging.INFO)
    served_by_fallback = [
        _chunk(content="Rest helps [1].", model="openai/gpt-5.4"),
        _chunk(finish_reason="stop", model="openai/gpt-5.4"),
    ]
    _install(monkeypatch, ai_settings, [tool_round(["dizziness"]), served_by_fallback])

    await _run()

    final = [r.getMessage() for r in caplog.records if "action=final_text" in r.getMessage()]
    assert len(final) == 1
    assert "model=openai/gpt-5.4" in final[0]


async def test_without_keys_mock_mode_cites_a_registered_source(monkeypatch, ai_settings):
    ai_settings.openrouter_api_key = ""
    ai_settings.anthropic_api_key = ""
    monkeypatch.setattr(stream_runtime, "get_settings", lambda: ai_settings)

    events, sources = await _run()

    text = "".join(_tokens(events))
    assert "[1]" in text
    assert "Sources:" not in text
    assert len(sources) == 1


async def test_sections_format_reaches_the_system_prompt(monkeypatch, ai_settings, searches):
    rounds = [tool_round(["coffee metformin"]), text_round("Yes.")]
    completions = _install(monkeypatch, ai_settings, rounds)

    sources = SourceRegistry()
    _ = [
        event
        async for event in stream_runtime.generate_response_events(
            question="Is coffee okay with metformin?",
            conversation_history=[],
            v10_digest=None,
            sources=sources,
            answer_format="sections",
        )
    ]

    system = completions.requests[0]["messages"][0]
    assert system["role"] == "system"
    assert "Watch for:" in system["content"]


async def test_default_format_keeps_the_old_system_prompt(monkeypatch, ai_settings, searches):
    completions = _install(monkeypatch, ai_settings, [tool_round(["coffee"]), text_round("Yes.")])

    await _run("Is coffee okay with metformin?")

    assert "Watch for:" not in completions.requests[0]["messages"][0]["content"]


# --- Cost accounting -----------------------------------------------------------


def _costed(chunks: list, cost: float) -> list:
    """OpenRouter puts the request's cost on the last chunk of each round."""
    chunks[-1].usage = SimpleNamespace(cost=cost)
    return chunks


async def _run_metered(meter: UsageMeter, question: str = "How should I manage dizziness?") -> None:
    async for _ in stream_runtime.generate_response_events(
        question=question,
        conversation_history=[],
        v10_digest=None,
        sources=SourceRegistry(),
        meter=meter,
    ):
        pass


async def test_reported_round_costs_and_searches_reach_the_meter(
    monkeypatch, ai_settings, searches
):
    meter = UsageMeter(search_cost_usd=0.016)
    _install(
        monkeypatch,
        ai_settings,
        [_costed(tool_round(["a", "b"]), 0.02), _costed(text_round("Done."), 0.03)],
    )

    await _run_metered(meter)

    assert meter.model_cost_usd == pytest.approx(0.05)
    assert meter.searches == 2


async def test_cost_in_a_chunk_without_choices_is_counted(monkeypatch, ai_settings, searches):
    meter = UsageMeter()
    usage_only = SimpleNamespace(choices=[], usage=SimpleNamespace(cost=0.01))
    _install(monkeypatch, ai_settings, [[*text_round("Hello there."), usage_only]])

    await _run_metered(meter)

    assert meter.model_cost_usd == pytest.approx(0.01)


async def test_round_without_reported_cost_is_charged_an_estimate(
    monkeypatch, ai_settings, searches
):
    meter = UsageMeter()
    _install(monkeypatch, ai_settings, [tool_round(["a"]), text_round("Done.")])

    await _run_metered(meter)

    assert meter.model_cost_usd == pytest.approx(2 * stream_runtime.UNMETERED_ROUND_COST_USD)


async def test_interrupted_round_is_charged_an_estimate(monkeypatch, ai_settings, searches):
    meter = UsageMeter()
    _install(monkeypatch, ai_settings, [[_chunk(content="Partial"), RuntimeError("cut")]])

    with pytest.raises(APIError):
        await _run_metered(meter)

    assert meter.model_cost_usd == pytest.approx(stream_runtime.UNMETERED_ROUND_COST_USD)


async def test_refused_request_is_not_charged(monkeypatch, ai_settings, searches):
    meter = UsageMeter()
    _install(monkeypatch, ai_settings, [_FakeAPIError(400)])

    with pytest.raises(APIError):
        await _run_metered(meter)

    assert meter.model_cost_usd == 0


async def test_cost_limit_stops_research_and_forces_the_answer(monkeypatch, ai_settings, searches):
    ai_settings.question_cost_limit_usd = 0.35
    meter = UsageMeter()
    completions = _install(
        monkeypatch, ai_settings, [_costed(tool_round(["a"]), 0.40), text_round("Done.")]
    )

    await _run_metered(meter)

    assert "tools" not in completions.requests[1]
    assert len(completions.requests) == 2
