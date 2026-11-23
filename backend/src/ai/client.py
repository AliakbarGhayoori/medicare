from __future__ import annotations

from typing import Any

from openai import AsyncOpenAI

from src.config import get_settings

_client: AsyncOpenAI | None = None


def get_openai_client() -> AsyncOpenAI:
    global _client
    if _client is None:
        settings = get_settings()
        api_key = settings.openrouter_api_key or settings.anthropic_api_key
        default_headers: dict[str, str] = {}
        if settings.openrouter_site_url:
            default_headers["HTTP-Referer"] = settings.openrouter_site_url
        if settings.openrouter_app_name:
            default_headers["X-Title"] = settings.openrouter_app_name

        _client = AsyncOpenAI(
            api_key=api_key,
            base_url=f"{settings.openrouter_base_url}/v1",
            default_headers=default_headers or None,
        )
    return _client


def chat_model_options(settings: Any) -> dict[str, Any]:
    """Model selection shared by every chat completion call.

    Adds OpenRouter's ``models`` fallback list (tried in order when the primary
    model fails) and an optional reasoning effort.
    """
    options: dict[str, Any] = {"model": settings.ai_model}
    extra_body: dict[str, Any] = {}
    fallbacks = [m for m in settings.ai_fallback_models if m and m != settings.ai_model]
    if fallbacks:
        extra_body["models"] = [settings.ai_model, *fallbacks]
    if settings.ai_reasoning_effort:
        extra_body["reasoning"] = {"effort": settings.ai_reasoning_effort}
    if extra_body:
        options["extra_body"] = extra_body
    return options
