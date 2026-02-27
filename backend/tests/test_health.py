from __future__ import annotations


async def test_health(api_client):
    response = await api_client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert response.json()["version"] == "3.0"
    assert response.headers.get("X-Request-ID")
