from __future__ import annotations

from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


class FontSize(StrEnum):
    regular = "regular"
    large = "large"
    extra_large = "extraLarge"


class SettingsResponse(BaseModel):
    font_size: FontSize = Field(FontSize.large, alias="fontSize")
    high_contrast: bool = Field(False, alias="highContrast")
    disclaimer_accepted_at: datetime | None = Field(None, alias="disclaimerAcceptedAt")
    disclaimer_version: str | None = Field(None, alias="disclaimerVersion")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)

    @field_validator("disclaimer_accepted_at", mode="before")
    @classmethod
    def _utc_accepted(cls, v: datetime | None) -> datetime | None:
        return _ensure_utc(v) if isinstance(v, datetime) else v


class SettingsUpdate(BaseModel):
    font_size: FontSize | None = Field(None, alias="fontSize")
    high_contrast: bool | None = Field(None, alias="highContrast")

    model_config = ConfigDict(populate_by_name=True)


class AcceptDisclaimerRequest(BaseModel):
    disclaimer_version: str = Field(..., alias="disclaimerVersion", min_length=1, max_length=20)

    model_config = ConfigDict(populate_by_name=True)


class AcceptDisclaimerResponse(BaseModel):
    accepted: bool = True
    disclaimer_version: str = Field(..., alias="disclaimerVersion")
    accepted_at: datetime = Field(..., alias="acceptedAt")

    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)
