from __future__ import annotations

from types import SimpleNamespace

from src.ai import client as ai_client


class _FakeAsyncAnthropic:
    def __init__(self, **kwargs):  # noqa: ANN003
        self.kwargs = kwargs


def test_get_anthropic_client_uses_openrouter_configuration(monkeypatch) -> None:
    settings = SimpleNamespace(
        ai_provider="openrouter",
        openrouter_api_key="or-key",
        anthropic_api_key="",
        openrouter_base_url="https://openrouter.ai/api/v1/anthropic",
        openrouter_site_url="https://medicare-ai.example",
        openrouter_app_name="MediCare AI",
    )

    monkeypatch.setattr(ai_client, "AsyncAnthropic", _FakeAsyncAnthropic)
    monkeypatch.setattr(ai_client, "get_settings", lambda: settings)
    ai_client._client = None

    client = ai_client.get_anthropic_client()
    assert isinstance(client, _FakeAsyncAnthropic)
    assert client.kwargs["api_key"] == "or-key"
    assert client.kwargs["base_url"] == settings.openrouter_base_url
    assert client.kwargs["default_headers"]["HTTP-Referer"] == settings.openrouter_site_url
    assert client.kwargs["default_headers"]["X-Title"] == settings.openrouter_app_name

    ai_client._client = None


def test_get_anthropic_client_defaults_to_anthropic_provider(monkeypatch) -> None:
    settings = SimpleNamespace(
        ai_provider="anthropic",
        openrouter_api_key="",
        anthropic_api_key="ant-key",
        openrouter_base_url="https://openrouter.ai/api/v1/anthropic",
        openrouter_site_url="",
        openrouter_app_name="MediCare AI",
    )

    monkeypatch.setattr(ai_client, "AsyncAnthropic", _FakeAsyncAnthropic)
    monkeypatch.setattr(ai_client, "get_settings", lambda: settings)
    ai_client._client = None

    client = ai_client.get_anthropic_client()
    assert isinstance(client, _FakeAsyncAnthropic)
    assert client.kwargs == {"api_key": "ant-key"}

    ai_client._client = None
