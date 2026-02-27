from __future__ import annotations


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
