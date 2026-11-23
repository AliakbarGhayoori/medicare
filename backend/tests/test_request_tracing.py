from __future__ import annotations

import asyncio
import logging

from src.api import chat as chat_api
from src.logging_config import JSONFormatter


async def test_request_id_echo_health(api_client):
    response = await api_client.get("/health", headers={"X-Request-ID": "req-123"})
    assert response.status_code == 200
    assert response.headers.get("X-Request-ID") == "req-123"


async def test_request_id_present_on_validation_error(api_client, auth_headers):
    response = await api_client.put(
        "/api/profile/v10",
        headers={**auth_headers, "X-Request-ID": "req-err-1"},
        json={"digest": ""},
    )
    assert response.status_code == 422
    assert response.headers.get("X-Request-ID") == "req-err-1"
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def _request_logs(caplog) -> list[logging.LogRecord]:  # noqa: ANN001
    return [r for r in caplog.records if r.getMessage() == "request_complete"]


async def test_health_checks_are_not_logged(api_client, caplog):
    caplog.set_level(logging.INFO)

    response = await api_client.get("/health")

    assert response.status_code == 200
    assert _request_logs(caplog) == []


async def test_api_requests_are_still_logged(api_client, auth_headers, caplog):
    caplog.set_level(logging.INFO)

    response = await api_client.get("/api/profile/v10", headers=auth_headers)

    assert response.status_code == 200
    assert [r.endpoint for r in _request_logs(caplog)] == ["/api/profile/v10"]


async def test_chat_request_logs_contain_no_question_text(
    monkeypatch, api_client, auth_headers, caplog
):
    caplog.set_level(logging.DEBUG)
    marker = "zebra-knee-ache-7731"
    updater_finished = asyncio.Event()
    real_updater = chat_api.update_v10_after_conversation

    async def _tracked_updater(**kwargs):  # noqa: ANN003, ANN202
        try:
            return await real_updater(**kwargs)
        finally:
            updater_finished.set()

    monkeypatch.setattr(chat_api, "update_v10_after_conversation", _tracked_updater)

    response = await api_client.post(
        "/api/chat/ask",
        json={"question": f"Why does my {marker} hurt at night?"},
        headers=auth_headers,
    )
    assert response.status_code == 200
    await asyncio.wait_for(updater_finished.wait(), timeout=5)

    formatter = JSONFormatter()
    written = [formatter.format(record) for record in caplog.records]
    assert any('"chat_response_complete"' in line for line in written)
    assert not [line for line in written if marker in line]
