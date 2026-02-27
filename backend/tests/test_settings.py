from __future__ import annotations


async def test_settings_requires_auth(api_client):
    response = await api_client.get("/api/settings")
    assert response.status_code == 401
    assert response.headers.get("X-Request-ID")
    body = response.json()
    assert body["error"]["code"] == "UNAUTHORIZED"


async def test_settings_get_and_update(api_client, auth_headers):
    response = await api_client.get("/api/settings", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["fontSize"] == "large"
    assert response.json()["highContrast"] is False

    update = await api_client.put(
        "/api/settings",
        headers=auth_headers,
        json={"fontSize": "extraLarge", "highContrast": True},
    )
    assert update.status_code == 200
    assert update.json()["fontSize"] == "extraLarge"
    assert update.json()["highContrast"] is True


async def test_accept_disclaimer(api_client, auth_headers):
    response = await api_client.post(
        "/api/settings/accept-disclaimer",
        headers=auth_headers,
        json={"disclaimerVersion": "1.0"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["accepted"] is True
    assert payload["disclaimerVersion"] == "1.0"
    assert payload["acceptedAt"] is not None
