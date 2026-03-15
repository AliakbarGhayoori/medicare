from __future__ import annotations

from types import SimpleNamespace

from src.ai import client as ai_client


class _FakeAsyncOpenAI:
    def __init__(self, **kwargs):  # noqa: ANN003
        self.kwargs = kwargs


def test_get_openai_client_uses_openrouter_configuration(
    monkeypatch,
) -> None:
    settings = SimpleNamespace(
        openrouter_api_key="or-key",
        anthropic_api_key="",
        openrouter_base_url="https://openrouter.ai/api",
        openrouter_site_url="https://medicare-ai.example",
        openrouter_app_name="MediCare AI",
    )

    monkeypatch.setattr(ai_client, "AsyncOpenAI", _FakeAsyncOpenAI)
    monkeypatch.setattr(ai_client, "get_settings", lambda: settings)
    ai_client._client = None

    client = ai_client.get_openai_client()
    assert isinstance(client, _FakeAsyncOpenAI)
    assert client.kwargs["api_key"] == "or-key"
    assert client.kwargs["base_url"] == "https://openrouter.ai/api/v1"
    assert client.kwargs["default_headers"]["HTTP-Referer"] == settings.openrouter_site_url
    assert client.kwargs["default_headers"]["X-Title"] == settings.openrouter_app_name

    ai_client._client = None


def test_get_openai_client_uses_anthropic_key_as_fallback(
    monkeypatch,
) -> None:
    settings = SimpleNamespace(
        openrouter_api_key="",
        anthropic_api_key="ant-key",
        openrouter_base_url="https://openrouter.ai/api",
        openrouter_site_url="",
        openrouter_app_name="",
    )

    monkeypatch.setattr(ai_client, "AsyncOpenAI", _FakeAsyncOpenAI)
    monkeypatch.setattr(ai_client, "get_settings", lambda: settings)
    ai_client._client = None

    client = ai_client.get_openai_client()
    assert isinstance(client, _FakeAsyncOpenAI)
    assert client.kwargs["api_key"] == "ant-key"
    assert client.kwargs["base_url"] == "https://openrouter.ai/api/v1"

    ai_client._client = None
