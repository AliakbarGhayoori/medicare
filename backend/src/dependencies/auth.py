from __future__ import annotations

import logging

from fastapi import Header
from firebase_admin import auth, credentials, initialize_app
from pydantic import BaseModel

from src.config import get_settings
from src.exceptions import APIError

logger = logging.getLogger(__name__)


class AuthUser(BaseModel):
    uid: str
    email: str | None = None


_firebase_initialized = False


def _ensure_firebase_initialized() -> None:
    global _firebase_initialized
    if _firebase_initialized:
        return

    settings = get_settings()
    if (
        not settings.firebase_project_id
        or not settings.firebase_client_email
        or not settings.firebase_private_key
    ):
        raise APIError(500, "INTERNAL_ERROR", "Firebase Admin credentials are not configured.")

    cred = credentials.Certificate(
        {
            "type": "service_account",
            "project_id": settings.firebase_project_id,
            "client_email": settings.firebase_client_email,
            "private_key": settings.firebase_private_key.replace("\\n", "\n"),
            "token_uri": "https://oauth2.googleapis.com/token",
        }
    )
    initialize_app(cred)
    _firebase_initialized = True


def _parse_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise APIError(401, "UNAUTHORIZED", "Missing bearer token.")
    if not authorization.startswith("Bearer "):
        raise APIError(401, "UNAUTHORIZED", "Invalid authorization header format.")
    return authorization.split(" ", 1)[1].strip()


async def get_current_user(authorization: str | None = Header(default=None)) -> AuthUser:
    token = _parse_bearer_token(authorization)
    settings = get_settings()

    if settings.auth_mode == "mock":
        if token.startswith("mock:") and len(token.split(":", 1)[1]) > 0:
            uid = token.split(":", 1)[1]
            return AuthUser(uid=uid, email=f"{uid}@example.com")
        raise APIError(401, "UNAUTHORIZED", "Mock mode requires token format 'Bearer mock:<uid>'.")

    _ensure_firebase_initialized()

    try:
        decoded = auth.verify_id_token(token)
    except auth.ExpiredIdTokenError as exc:
        logger.warning("Firebase token EXPIRED: %s", exc)
        raise APIError(401, "TOKEN_EXPIRED", "Firebase token has expired.") from exc
    except auth.InvalidIdTokenError as exc:
        logger.warning("Firebase token INVALID: %s", exc)
        raise APIError(401, "UNAUTHORIZED", "Invalid Firebase token.") from exc
    except Exception as exc:  # pragma: no cover - defensive for SDK internals
        logger.warning("Firebase auth FAILED (%s): %s", type(exc).__name__, exc)
        raise APIError(401, "UNAUTHORIZED", "Authentication failed.") from exc

    uid = decoded.get("uid")
    if not uid:
        raise APIError(401, "UNAUTHORIZED", "Token does not contain uid.")

    return AuthUser(uid=uid, email=decoded.get("email"))
