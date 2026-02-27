from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from mongomock_motor import AsyncMongoMockClient

# Set environment before importing app/settings.
os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("AUTH_MODE", "mock")
os.environ.setdefault("MOCK_AI", "true")
os.environ.setdefault("MONGODB_URI", "mongodb://localhost:27017")
os.environ.setdefault("MONGODB_DATABASE", "test-medicare")
os.environ.setdefault("ALLOWED_ORIGINS", '["http://localhost:3000"]')
os.environ.setdefault("FIREBASE_PROJECT_ID", "test")
os.environ.setdefault("FIREBASE_CLIENT_EMAIL", "test@test.com")
os.environ.setdefault("FIREBASE_PRIVATE_KEY", "test")
os.environ.setdefault("ANTHROPIC_API_KEY", "")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.config import reload_settings  # noqa: E402
from src.dependencies.database import get_db  # noqa: E402
from src.main import app  # noqa: E402


@pytest_asyncio.fixture
async def mock_db():
    reload_settings()
    client = AsyncMongoMockClient()
    db = client["test-medicare"]
    yield db
    await client.drop_database("test-medicare")


@pytest_asyncio.fixture
async def api_client(mock_db):
    async def _override_get_db():
        return mock_db

    app.dependency_overrides[get_db] = _override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()


@pytest.fixture
def auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer mock:test_uid"}
