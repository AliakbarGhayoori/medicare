from motor.motor_asyncio import AsyncIOMotorDatabase

from src.db.mongo import get_database


async def get_db() -> AsyncIOMotorDatabase:
    return get_database()
