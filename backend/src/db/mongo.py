from __future__ import annotations

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from src.config import get_settings

_client: AsyncIOMotorClient | None = None


async def connect_to_mongo() -> None:
    global _client
    settings = get_settings()
    if _client is not None:
        return

    _client = AsyncIOMotorClient(
        settings.mongodb_uri,
        maxPoolSize=20,
        minPoolSize=2,
        serverSelectionTimeoutMS=5000,
    )
    await _client.admin.command("ping")


def get_client() -> AsyncIOMotorClient:
    global _client
    if _client is None:
        settings = get_settings()
        _client = AsyncIOMotorClient(
            settings.mongodb_uri,
            maxPoolSize=20,
            minPoolSize=2,
            serverSelectionTimeoutMS=5000,
        )
    return _client


def get_database() -> AsyncIOMotorDatabase:
    settings = get_settings()
    return get_client()[settings.mongodb_database]


async def close_mongo_connection() -> None:
    global _client
    if _client is not None:
        _client.close()
        _client = None
