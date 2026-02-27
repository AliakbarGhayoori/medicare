from __future__ import annotations

from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _ensure_utc(dt: datetime) -> datetime:
    """Attach UTC timezone to naive datetimes (e.g. from MongoDB)."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


class V10DigestResponse(BaseModel):
    digest: str | None
    previous_digest: str | None = Field(None, alias="previousDigest")
    can_revert: bool = Field(False, alias="canRevert")
    version: int = 0
    updated_at: datetime | None = Field(None, alias="updatedAt")
    last_update_source: str | None = Field(None, alias="lastUpdateSource")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)

    @field_validator("updated_at", mode="before")
    @classmethod
    def _utc_updated(cls, v: datetime | None) -> datetime | None:
        return _ensure_utc(v) if isinstance(v, datetime) else v


class V10DigestUpdate(BaseModel):
    digest: str = Field(..., min_length=1, max_length=5000)
