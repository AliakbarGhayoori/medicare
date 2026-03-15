from __future__ import annotations

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
