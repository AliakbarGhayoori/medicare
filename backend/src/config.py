from __future__ import annotations

import json
import os
from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=os.getenv("MEDICARE_ENV_FILE", ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Firebase
    firebase_project_id: str = ""
    firebase_client_email: str = ""
    firebase_private_key: str = ""

    # MongoDB
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_database: str = "medicare-ai"

    # Anthropic
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-opus-4-6-20250219"
    anthropic_max_tokens: int = 4096
    ai_temperature: float = 0.3
    ai_provider: str = "anthropic"  # anthropic | openrouter
    openrouter_api_key: str = ""
    openrouter_base_url: str = "https://openrouter.ai/api/v1/anthropic"
    openrouter_site_url: str = ""
    openrouter_app_name: str = "MediCare AI"

    # Search backend (Tavily)
    tavily_api_key: str = ""
    tavily_base_url: str = "https://api.tavily.com"
    tavily_search_depth: str = "advanced"
    tavily_include_answer: str = "advanced"
    tavily_include_favicon: bool = True
    tavily_max_results: int = 6
    tavily_timeout_seconds: float = 20.0
    ai_tool_min_calls: int = 3
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
    chat_rate_limit_per_hour: int = 30
    v10_rate_limit_per_hour: int = 10

    @field_validator("allowed_origins", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value: list[str] | str) -> list[str]:
        if isinstance(value, list):
            return value
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            if stripped.startswith("["):
                parsed = json.loads(stripped)
                if isinstance(parsed, list):
                    return [str(item) for item in parsed]
            return [item.strip() for item in stripped.split(",") if item.strip()]
        return ["http://localhost:3000"]


@lru_cache
def get_settings() -> Settings:
    return Settings()


def reload_settings() -> Settings:
    get_settings.cache_clear()
    return get_settings()
