from __future__ import annotations


async def test_profile_v10_get_empty(api_client, auth_headers):
    response = await api_client.get("/api/profile/v10", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["digest"] is None
    assert response.json()["canRevert"] is False
    assert response.json()["version"] == 0


async def test_profile_v10_update(api_client, auth_headers):
    update = await api_client.put(
        "/api/profile/v10",
        headers=auth_headers,
        json={"digest": "Conditions: Hypertension"},
    )
    assert update.status_code == 200
    payload = update.json()
    assert payload["digest"] == "Conditions: Hypertension"
    assert payload["canRevert"] is False
    assert payload["version"] == 1
    assert payload["lastUpdateSource"] == "manual"

    fetched = await api_client.get("/api/profile/v10", headers=auth_headers)
    assert fetched.status_code == 200
    assert fetched.json()["digest"] == "Conditions: Hypertension"


async def test_profile_v10_revert(api_client, auth_headers):
    first = await api_client.put(
        "/api/profile/v10",
        headers=auth_headers,
        json={"digest": "Conditions: Hypertension"},
    )
    assert first.status_code == 200

    second = await api_client.put(
        "/api/profile/v10",
        headers=auth_headers,
        json={"digest": "Conditions: Diabetes"},
    )
    assert second.status_code == 200
    assert second.json()["canRevert"] is True
    assert second.json()["previousDigest"] == "Conditions: Hypertension"

    reverted = await api_client.post("/api/profile/v10/revert", headers=auth_headers)
    assert reverted.status_code == 200
    assert reverted.json()["digest"] == "Conditions: Hypertension"
    assert reverted.json()["lastUpdateSource"] == "manual"


async def test_profile_v10_revert_without_previous_is_noop(api_client, auth_headers):
    first = await api_client.put(
        "/api/profile/v10",
        headers=auth_headers,
        json={"digest": "Conditions: Asthma"},
    )
    assert first.status_code == 200
    assert first.json()["canRevert"] is False

    reverted = await api_client.post("/api/profile/v10/revert", headers=auth_headers)
    assert reverted.status_code == 200
    assert reverted.json()["digest"] == "Conditions: Asthma"
    assert reverted.json()["canRevert"] is False
