from __future__ import annotations

from types import SimpleNamespace

from src.services import analytics as analytics_service
from src.services.analytics import _sanitize_properties


async def test_chat_rate_limit_returns_retry_after(api_client, auth_headers, monkeypatch):
    from src.api import chat as chat_api

    monkeypatch.setattr(
        chat_api,
        "check_rate_limit_with_retry",
        lambda *args, **kwargs: (False, 42),
    )

    response = await api_client.post(
        "/api/chat/ask",
        headers={**auth_headers, "Accept": "text/event-stream"},
        json={"question": "test"},
    )

    assert response.status_code == 429
    assert response.headers.get("Retry-After") == "42"
    assert response.json()["error"]["code"] == "RATE_LIMITED"


def test_analytics_sanitization_filters_text_fields() -> None:
    sanitized = _sanitize_properties(
        {
            "content": "private text",
            "questionText": "private text",
            "citationCount": 3,
            "hasEmergency": True,
            "tags": ["safe", 1, False, {"x": "y"}],
            "nested": {"a": "ok", "b": 1, "c": [1, 2]},
        }
    )

    assert "content" not in sanitized
    assert "questionText" not in sanitized
    assert sanitized["citationCount"] == 3
    assert sanitized["hasEmergency"] is True
    assert sanitized["tags"] == ["safe", 1, False]
    assert sanitized["nested"] == {"a": "ok", "b": 1}


async def test_track_event_persists_sanitized_payload_when_enabled(mock_db, monkeypatch) -> None:
    settings = SimpleNamespace(analytics_enabled=True, analytics_store_db=True)
    monkeypatch.setattr(analytics_service, "get_settings", lambda: settings)

    await analytics_service.track_event(
        mock_db,
        "question_asked",
        "uid_1",
        {
            "questionText": "private",
            "response": "private",
            "citationCount": 2,
        },
    )

    stored = await mock_db.analyticsEvents.find_one({"event": "question_asked"})
    assert stored is not None
    assert stored["firebaseUid"] == "uid_1"
    assert stored["properties"] == {"citationCount": 2}


async def test_track_event_skips_db_when_storage_disabled(mock_db, monkeypatch) -> None:
    settings = SimpleNamespace(analytics_enabled=True, analytics_store_db=False)
    monkeypatch.setattr(analytics_service, "get_settings", lambda: settings)

    await analytics_service.track_event(
        mock_db,
        "settings_changed",
        "uid_2",
        {"changedFields": ["fontSize"]},
    )

    stored = await mock_db.analyticsEvents.find_one({"event": "settings_changed"})
    assert stored is None
