from __future__ import annotations

from anthropic import AsyncAnthropic

from src.config import get_settings

_client: AsyncAnthropic | None = None


def get_anthropic_client() -> AsyncAnthropic:
    global _client
    if _client is None:
        settings = get_settings()
        if settings.ai_provider == "openrouter":
            api_key = settings.openrouter_api_key or settings.anthropic_api_key
            headers: dict[str, str] = {}
            if settings.openrouter_site_url:
                headers["HTTP-Referer"] = settings.openrouter_site_url
            if settings.openrouter_app_name:
                headers["X-Title"] = settings.openrouter_app_name

            _client = AsyncAnthropic(
                api_key=api_key,
                base_url=settings.openrouter_base_url,
                default_headers=headers or None,
            )
        else:
            _client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    return _client
