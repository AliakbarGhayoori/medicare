from __future__ import annotations

from types import SimpleNamespace

import httpx
import pytest

from src.ai import tavily
from src.exceptions import APIError


class _FakeResponse:
    def __init__(self, status_code: int, payload: object) -> None:
        self.status_code = status_code
        self._payload = payload

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise httpx.HTTPStatusError(
                "error",
                request=httpx.Request("POST", "https://api.tavily.com/search"),
                response=self,
            )

    def json(self) -> object:
        return self._payload


class _FakeAsyncClient:
    def __init__(self, response: _FakeResponse) -> None:
        self._response = response
        self.post_calls: list[tuple[str, dict]] = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def post(self, url: str, json: dict):  # noqa: ANN003
        self.post_calls.append((url, json))
        return self._response


async def test_execute_tavily_search_normalizes_payload(monkeypatch):
    settings = SimpleNamespace(
        tavily_api_key="tvly-test",
        tavily_base_url="https://api.tavily.com",
        tavily_search_depth="advanced",
        tavily_include_answer="advanced",
        tavily_include_favicon=True,
        tavily_max_results=6,
        tavily_timeout_seconds=10.0,
    )
    payload = {
        "query": "query text",
        "answer": "summary",
        "request_id": "req-1",
        "response_time": 1.2,
        "results": [
            {
                "title": "Mayo Clinic",
                "url": "https://www.mayoclinic.org/example",
                "content": "A" * 2000,
                "favicon": "https://www.mayoclinic.org/icon.png",
                "score": 0.8,
            }
        ],
    }
    fake_client = _FakeAsyncClient(_FakeResponse(status_code=200, payload=payload))

    monkeypatch.setattr(tavily, "get_settings", lambda: settings)
    monkeypatch.setattr(tavily.httpx, "AsyncClient", lambda timeout: fake_client)

    result = await tavily.execute_tavily_search(query="query text")

    assert result["query"] == "query text"
    assert result["answer"] == "summary"
    assert len(result["results"]) == 1
    assert result["results"][0]["source"] == "mayoclinic.org"
    assert len(result["results"][0]["content"]) <= 1200
    assert fake_client.post_calls[0][0] == "https://api.tavily.com/search"
    assert fake_client.post_calls[0][1]["search_depth"] == "advanced"


async def test_execute_tavily_search_requires_api_key(monkeypatch):
    settings = SimpleNamespace(tavily_api_key="")
    monkeypatch.setattr(tavily, "get_settings", lambda: settings)

    with pytest.raises(APIError) as exc_info:
        await tavily.execute_tavily_search(query="dizziness")

    assert exc_info.value.code == "SEARCH_BACKEND_UNAVAILABLE"


async def test_include_answer_false_is_sent_as_boolean(monkeypatch):
    settings = SimpleNamespace(
        tavily_api_key="tvly-test",
        tavily_base_url="https://api.tavily.com",
        tavily_search_depth="advanced",
        tavily_include_answer="false",
        tavily_include_favicon=True,
        tavily_max_results=6,
        tavily_timeout_seconds=20.0,
    )
    fake_client = _FakeAsyncClient(_FakeResponse(200, {"query": "q", "results": []}))
    monkeypatch.setattr(tavily, "get_settings", lambda: settings)
    monkeypatch.setattr(tavily.httpx, "AsyncClient", lambda **_: fake_client)

    await tavily.execute_tavily_search("q")

    assert fake_client.post_calls[0][1]["include_answer"] is False


async def test_tavily_error_log_does_not_contain_query(monkeypatch, caplog):
    settings = SimpleNamespace(
        tavily_api_key="tvly-test",
        tavily_base_url="https://api.tavily.com",
        tavily_search_depth="advanced",
        tavily_include_answer="false",
        tavily_include_favicon=True,
        tavily_max_results=6,
        tavily_timeout_seconds=20.0,
    )
    fake_client = _FakeAsyncClient(_FakeResponse(500, {}))
    monkeypatch.setattr(tavily, "get_settings", lambda: settings)
    monkeypatch.setattr(tavily.httpx, "AsyncClient", lambda **_: fake_client)

    with pytest.raises(APIError):
        await tavily.execute_tavily_search("zebra-knee-ache-7731")

    assert all("zebra-knee-ache-7731" not in str(record.__dict__) for record in caplog.records)
