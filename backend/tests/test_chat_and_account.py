from __future__ import annotations


async def test_chat_stream_works(api_client, auth_headers):
    response = await api_client.post(
        "/api/chat/ask",
        headers={**auth_headers, "Accept": "text/event-stream"},
        json={"question": "I feel dizzy when I stand up"},
    )
    assert response.status_code == 200
    body = response.text
    assert "event: tool_use" in body
    assert "event: token" in body
    assert "event: done" in body


async def test_account_delete(api_client, auth_headers):
    await api_client.put(
        "/api/profile/v10",
        headers=auth_headers,
        json={"digest": "Conditions: Diabetes"},
    )

    deleted = await api_client.request(
        "DELETE",
        "/api/account",
        headers=auth_headers,
        json={"confirmation": "DELETE"},
    )
    assert deleted.status_code == 200
    assert deleted.json()["deleted"] is True

    # Account should be re-created lazily with defaults on next settings read.
    response = await api_client.get("/api/settings", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["fontSize"] == "large"


async def test_account_delete_requires_exact_confirmation(api_client, auth_headers):
    denied = await api_client.request(
        "DELETE",
        "/api/account",
        headers=auth_headers,
        json={"confirmation": "delete"},
    )
    assert denied.status_code == 422
    assert denied.json()["error"]["code"] == "VALIDATION_ERROR"
