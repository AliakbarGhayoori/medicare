from __future__ import annotations

from src.db.indexes import ensure_indexes


async def test_settings_load_when_email_belongs_to_deleted_account(
    api_client, auth_headers, mock_db
):
    """A Firebase account re-created with the same email gets a new uid.

    The user record left behind by the deleted account must not block the new
    account. Previously the unique email index raised DuplicateKeyError and every
    endpoint returned 500 for that person.
    """
    await ensure_indexes(mock_db)
    # Mock auth maps "Bearer mock:test_uid" to the email "test_uid@example.com".
    await mock_db.users.insert_one(
        {"firebaseUid": "deleted_account_uid", "email": "test_uid@example.com"}
    )

    response = await api_client.get("/api/settings", headers=auth_headers)

    assert response.status_code == 200
    assert await mock_db.users.count_documents({"firebaseUid": "test_uid"}) == 1


async def test_startup_removes_legacy_unique_email_index(mock_db):
    """Databases created by earlier versions still carry a unique email index."""
    await mock_db.users.create_index("email", unique=True, sparse=True)

    await ensure_indexes(mock_db)

    await mock_db.users.insert_one({"firebaseUid": "old_uid", "email": "same@example.com"})
    await mock_db.users.insert_one({"firebaseUid": "new_uid", "email": "same@example.com"})
    assert await mock_db.users.count_documents({"email": "same@example.com"}) == 2
