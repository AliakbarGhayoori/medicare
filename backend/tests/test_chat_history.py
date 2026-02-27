from __future__ import annotations


async def test_history_after_chat_round_trip(api_client, auth_headers):
    ask = await api_client.post(
        "/api/chat/ask",
        headers={**auth_headers, "Accept": "text/event-stream"},
        json={"question": "What causes dizziness when standing?"},
    )
    assert ask.status_code == 200

    history = await api_client.get("/api/chat/history", headers=auth_headers)
    assert history.status_code == 200
    payload = history.json()

    assert len(payload["conversations"]) == 1
    conversation_id = payload["conversations"][0]["id"]

    messages = await api_client.get(f"/api/chat/history/{conversation_id}", headers=auth_headers)
    assert messages.status_code == 200
    msg_payload = messages.json()

    assert msg_payload["conversationId"] == conversation_id
    assert len(msg_payload["messages"]) >= 2
    assert msg_payload["messages"][0]["role"] == "user"
    assert msg_payload["messages"][1]["role"] == "assistant"
