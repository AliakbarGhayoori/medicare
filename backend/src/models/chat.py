from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum

from bson import ObjectId
from pydantic import BaseModel, ConfigDict, Field, field_validator


def _ensure_utc(dt: datetime) -> datetime:
    """Attach UTC timezone to naive datetimes (e.g. from MongoDB)."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=2000)
    conversation_id: str | None = Field(None, alias="conversationId")

    model_config = ConfigDict(populate_by_name=True, str_strip_whitespace=True)

    @field_validator("question")
    @classmethod
    def validate_question(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Question cannot be empty.")
        return value

    @field_validator("conversation_id")
    @classmethod
    def validate_conversation_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if not ObjectId.is_valid(value):
            raise ValueError("conversationId must be a valid ObjectId.")
        return value


class Citation(BaseModel):
    number: int
    title: str
    source: str
    url: str
    snippet: str = ""


class ConfidenceLevel(StrEnum):
    high = "high"
    medium = "medium"
    low = "low"


class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    citations: list[Citation] = []
    confidence: ConfidenceLevel | None = None
    requires_emergency_care: bool = Field(False, alias="requiresEmergencyCare")
    created_at: datetime = Field(..., alias="createdAt")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)

    @field_validator("created_at", mode="before")
    @classmethod
    def _utc_created(cls, v: datetime) -> datetime:
        return _ensure_utc(v) if isinstance(v, datetime) else v


class ConversationSummary(BaseModel):
    id: str
    title: str
    last_message: str = Field("", alias="lastMessage")
    message_count: int = Field(0, alias="messageCount")
    created_at: datetime = Field(..., alias="createdAt")
    updated_at: datetime = Field(..., alias="updatedAt")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)

    @field_validator("created_at", "updated_at", mode="before")
    @classmethod
    def _utc_dates(cls, v: datetime) -> datetime:
        return _ensure_utc(v) if isinstance(v, datetime) else v


class ConversationListResponse(BaseModel):
    conversations: list[ConversationSummary]
    has_more: bool = Field(..., alias="hasMore")
    next_cursor: str | None = Field(None, alias="nextCursor")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)


class ConversationMessagesResponse(BaseModel):
    conversation_id: str = Field(..., alias="conversationId")
    messages: list[MessageResponse]
    has_more: bool = Field(..., alias="hasMore")
    next_cursor: str | None = Field(None, alias="nextCursor")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)
