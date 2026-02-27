#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys

import httpx


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run backend smoke checks.")
    parser.add_argument("--base-url", default="http://localhost:8000", help="API base URL.")
    parser.add_argument(
        "--token",
        default="mock:smoke_user",
        help="Bearer token value (without 'Bearer ').",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=20.0,
        help="Request timeout in seconds.",
    )
    return parser.parse_args()


def _require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)


def _auth_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }


def main() -> None:
    args = _parse_args()
    timeout = httpx.Timeout(args.timeout)

    with httpx.Client(base_url=args.base_url, timeout=timeout) as client:
        health = client.get("/health")
        _require(health.status_code == 200, f"/health returned {health.status_code}")
        payload = health.json()
        _require(payload.get("status") == "healthy", "Health payload status is not 'healthy'")
        print("[OK] Health check")

        settings = client.get("/api/settings", headers=_auth_headers(args.token))
        _require(settings.status_code == 200, f"/api/settings returned {settings.status_code}")
        print("[OK] Auth + settings check")

        chat = client.post(
            "/api/chat/ask",
            headers={
                **_auth_headers(args.token),
                "Accept": "text/event-stream",
                "Content-Type": "application/json",
            },
            json={"question": "I feel dizzy when standing up."},
        )
        _require(chat.status_code == 200, f"/api/chat/ask returned {chat.status_code}")

        body = chat.text
        _require("event: token" in body, "Chat stream did not contain token event")
        _require("event: done" in body, "Chat stream did not contain done event")

        done_line = next((line for line in body.splitlines() if line.startswith("data: {")), None)
        if done_line:
            try:
                json.loads(done_line[len("data: ") :])
            except json.JSONDecodeError:
                _require(False, "Chat stream data line was not valid JSON")

        print("[OK] Chat streaming check")

    print("[PASS] Smoke checks complete.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted")
        sys.exit(1)
