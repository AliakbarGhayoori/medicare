from __future__ import annotations

from types import SimpleNamespace

import pytest

from src.ai import client as ai_client
from src.config import Settings


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


def test_ai_model_env_takes_precedence_over_legacy_name(monkeypatch) -> None:
    monkeypatch.setenv("AI_MODEL", "a/x")
    monkeypatch.setenv("ANTHROPIC_MODEL", "b/y")
    assert Settings(_env_file=None).ai_model == "a/x"


def test_legacy_anthropic_model_env_still_selects_model(monkeypatch) -> None:
    monkeypatch.delenv("AI_MODEL", raising=False)
    monkeypatch.setenv("ANTHROPIC_MODEL", "b/y")
    assert Settings(_env_file=None).ai_model == "b/y"


def test_fallback_models_parse_from_comma_separated_env(monkeypatch) -> None:
    monkeypatch.setenv("AI_FALLBACK_MODELS", "openai/gpt-5.4, x/y")
    assert Settings(_env_file=None).ai_fallback_models == ["openai/gpt-5.4", "x/y"]


def test_fallback_models_parse_from_json_env(monkeypatch) -> None:
    monkeypatch.setenv("AI_FALLBACK_MODELS", '["openai/gpt-5.4"]')
    assert Settings(_env_file=None).ai_fallback_models == ["openai/gpt-5.4"]


def test_chat_model_options_adds_openrouter_fallback_list() -> None:
    settings = SimpleNamespace(
        ai_model="google/gemini-4-neon",
        ai_fallback_models=["google/gemini-4-neon", "openai/gpt-5.4"],
        ai_reasoning_effort=None,
    )
    assert ai_client.chat_model_options(settings) == {
        "model": "google/gemini-4-neon",
        "extra_body": {
            "models": ["google/gemini-4-neon", "openai/gpt-5.4"],
            "usage": {"include": True},
        },
    }


def test_chat_model_options_always_asks_for_the_cost() -> None:
    settings = SimpleNamespace(ai_model="m", ai_fallback_models=[], ai_reasoning_effort=None)
    assert ai_client.chat_model_options(settings) == {
        "model": "m",
        "extra_body": {"usage": {"include": True}},
    }


def test_chat_model_options_passes_reasoning_effort() -> None:
    settings = SimpleNamespace(ai_model="m", ai_fallback_models=[], ai_reasoning_effort="low")
    assert ai_client.chat_model_options(settings)["extra_body"]["reasoning"] == {"effort": "low"}


@pytest.mark.parametrize(
    ("usage", "expected"),
    [
        (SimpleNamespace(cost=0.0123), 0.0123),
        ({"cost": "0.5"}, 0.5),
        (SimpleNamespace(prompt_tokens=3), None),
        (None, None),
        (SimpleNamespace(cost="n/a"), None),
        (SimpleNamespace(cost=-1), None),
    ],
)
def test_reported_cost_reads_openrouter_usage(usage, expected) -> None:  # noqa: ANN001
    assert ai_client.reported_cost(usage) == expected
