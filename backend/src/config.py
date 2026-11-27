from __future__ import annotations

import json
import os
from functools import lru_cache
from typing import Annotated

from pydantic import AliasChoices, Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


def _parse_str_list(value: object, default: list[str]) -> list[str]:
    """Accept a list, a JSON list string, or a comma-separated string."""
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return []
        if stripped.startswith("["):
            parsed = json.loads(stripped)
            if isinstance(parsed, list):
                return [str(item) for item in parsed]
        return [item.strip() for item in stripped.split(",") if item.strip()]
    return default


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=os.getenv("MEDICARE_ENV_FILE", ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        populate_by_name=True,
    )

    # Firebase
    firebase_project_id: str = ""
    firebase_client_email: str = ""
    firebase_private_key: str = ""

    # MongoDB
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_database: str = "medicare-ai"

    # AI model, called through OpenRouter's OpenAI-compatible chat completions API.
    # ANTHROPIC_* names are accepted for backward compatibility with older env files.
    anthropic_api_key: str = ""
    ai_model: str = Field(
        default="google/gemini-4-neon",
        validation_alias=AliasChoices("AI_MODEL", "ANTHROPIC_MODEL"),
    )
    # OpenRouter tries these in order when the primary model fails.
    ai_fallback_models: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["openai/gpt-5.4"]
    )
    ai_max_tokens: int = Field(
        default=8192,
        validation_alias=AliasChoices("AI_MAX_TOKENS", "ANTHROPIC_MAX_TOKENS"),
    )
    ai_reasoning_effort: str | None = None  # low | medium | high; None = provider default
    ai_temperature: float = 0.3
    ai_provider: str = "anthropic"  # anthropic | openrouter
    openrouter_api_key: str = ""
    openrouter_base_url: str = "https://openrouter.ai/api"
    openrouter_site_url: str = ""
    openrouter_app_name: str = "MediCare AI"

    # Search backend (Tavily)
    tavily_api_key: str = ""
    tavily_base_url: str = "https://api.tavily.com"
    tavily_search_depth: str = "advanced"
    tavily_include_answer: str = "false"  # the answer cites only numbered results
    tavily_include_favicon: bool = True
    tavily_max_results: int = 6
    tavily_timeout_seconds: float = 20.0
    ai_tool_min_calls: int = 2
    ai_tool_max_rounds: int = 6
    ai_tool_max_calls: int = 12

    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_version: str = "3.0"
    environment: str = "development"
    allowed_origins: list[str] = Field(default_factory=lambda: ["http://localhost:3000"])

    # Runtime behavior
    auth_mode: str = "firebase"  # firebase | mock
    mock_ai: bool = False
    max_conversation_context_messages: int = 20
    max_question_length: int = 2000
    sse_chunk_size: int = 48
    v10_auto_update_enabled: bool = True
    disclaimer_current_version: str = "1.0"
    analytics_enabled: bool = True
    analytics_store_db: bool = False

    # Rate limits
    chat_rate_limit_per_hour: int = 10  # questions per user
    v10_rate_limit_per_hour: int = 10

    # Usage limits (see services/usage_limits.py). Costs are in US dollars, months
    # and days in UTC.
    chat_questions_per_day: int = 20  # per user
    ip_questions_per_hour: int = 30  # per internet address, across accounts
    user_monthly_budget_usd: float = 2.50
    monthly_budget_usd: float = 10.0  # the whole service: model + web search
    daily_budget_usd: float = 2.0  # the whole service, so one bad day can't spend the month
    question_cost_limit_usd: float = 0.30  # an answer stops searching once it has cost this
    question_cost_reserve_usd: float = 0.50  # held back for each answer in progress
    tavily_cost_per_credit_usd: float = 0.008  # pay-as-you-go price; advanced search = 2 credits

    @field_validator("allowed_origins", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value: list[str] | str) -> list[str]:
        return _parse_str_list(value, default=["http://localhost:3000"])

    @field_validator("ai_fallback_models", mode="before")
    @classmethod
    def parse_fallback_models(cls, value: list[str] | str) -> list[str]:
        return _parse_str_list(value, default=[])


@lru_cache
def get_settings() -> Settings:
    return Settings()


def reload_settings() -> Settings:
    get_settings.cache_clear()
    return get_settings()
