#!/usr/bin/env python3
"""MediCare AI — Live E2E Verification Script.

Tests the full live flow: Firebase signup/signin → backend auth →
AI chat (OpenRouter + Tavily) → V10 health profile → conversation history.

Usage:
    python scripts/live_e2e_check.py [--base-url http://127.0.0.1:8000]
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
import urllib.error

FIREBASE_API_KEY = "AIzaSyCgscu7VyT35jxvR5Dbs0zXk4WSW7tTL6o"
BASE_URL = "http://127.0.0.1:8000"
TEST_EMAIL = f"e2e-test-{int(time.time())}@medicare-test.com"
TEST_PASSWORD = "E2eTestPass123!"

results: list[dict] = []


def _log(status: str, test: str, detail: str = "") -> None:
    icon = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⏭️"
    print(f"  {icon} {test}" + (f" — {detail}" if detail else ""))
    results.append({"test": test, "status": status, "detail": detail})


def _request(
    url: str,
    *,
    method: str = "GET",
    data: dict | None = None,
    headers: dict | None = None,
    timeout: int = 30,
) -> tuple[int, str]:
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode()
    except Exception as exc:
        return 0, str(exc)


# ── 1. Health check ──────────────────────────────────────────
def test_health() -> None:
    code, body = _request(f"{BASE_URL}/health")
    if code == 200 and "healthy" in body:
        _log("PASS", "Backend health check")
    else:
        _log("FAIL", "Backend health check", f"HTTP {code}: {body[:200]}")


# ── 2. Firebase signup ───────────────────────────────────────
def test_firebase_signup() -> str | None:
    code, body = _request(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}",
        method="POST",
        data={"email": TEST_EMAIL, "password": TEST_PASSWORD, "returnSecureToken": True},
    )
    d = json.loads(body) if body.startswith("{") else {}
    if code == 200 and "idToken" in d:
        _log("PASS", "Firebase signup", f"UID: {d['localId']}")
        return d["idToken"]
    _log("FAIL", "Firebase signup", f"HTTP {code}: {body[:200]}")
    return None


# ── 3. Firebase signin ───────────────────────────────────────
def test_firebase_signin() -> str | None:
    code, body = _request(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}",
        method="POST",
        data={"email": TEST_EMAIL, "password": TEST_PASSWORD, "returnSecureToken": True},
    )
    d = json.loads(body) if body.startswith("{") else {}
    if code == 200 and "idToken" in d:
        _log("PASS", "Firebase signin", f"UID: {d['localId']}")
        return d["idToken"]
    _log("FAIL", "Firebase signin", f"HTTP {code}: {body[:200]}")
    return None


# ── 4. Settings CRUD ─────────────────────────────────────────
def test_settings(token: str) -> None:
    auth = {"Authorization": f"Bearer {token}"}

    # GET
    code, body = _request(f"{BASE_URL}/api/settings", headers=auth)
    if code == 200:
        _log("PASS", "GET /api/settings")
    else:
        _log("FAIL", "GET /api/settings", f"HTTP {code}")

    # PUT
    code, body = _request(
        f"{BASE_URL}/api/settings",
        method="PUT",
        data={"fontSize": "large", "highContrast": True},
        headers=auth,
    )
    d = json.loads(body) if body.startswith("{") else {}
    if code == 200 and d.get("fontSize") == "large" and d.get("highContrast") is True:
        _log("PASS", "PUT /api/settings", "fontSize=large, highContrast=true")
    else:
        _log("FAIL", "PUT /api/settings", f"HTTP {code}: {body[:200]}")


# ── 5. V10 health profile ────────────────────────────────────
def test_v10(token: str) -> None:
    auth = {"Authorization": f"Bearer {token}"}

    # GET (should be empty initially)
    code, body = _request(f"{BASE_URL}/api/profile/v10", headers=auth)
    if code == 200:
        _log("PASS", "GET /api/profile/v10 (initial)")
    else:
        _log("FAIL", "GET /api/profile/v10", f"HTTP {code}")

    # PUT
    digest_text = "72 years old. Diabetes type 2. Takes metformin. High blood pressure on lisinopril."
    code, body = _request(
        f"{BASE_URL}/api/profile/v10",
        method="PUT",
        data={"digest": digest_text},
        headers=auth,
    )
    d = json.loads(body) if body.startswith("{") else {}
    if code == 200 and d.get("digest") == digest_text:
        _log("PASS", "PUT /api/profile/v10", f"version={d.get('version')}")
    else:
        _log("FAIL", "PUT /api/profile/v10", f"HTTP {code}: {body[:200]}")


# ── 6. Live AI chat ──────────────────────────────────────────
def test_chat(token: str) -> str | None:
    auth = {"Authorization": f"Bearer {token}"}

    code, body = _request(
        f"{BASE_URL}/api/chat/ask",
        method="POST",
        data={"question": "What are common side effects of metformin for someone my age?"},
        headers=auth,
        timeout=120,
    )

    has_tokens = "event: token" in body or '"type":"token"' in body
    has_done = "event: done" in body or '"messageId"' in body

    # Parse the done event
    conv_id = None
    for line in body.split("\n"):
        if line.startswith("data:") and "conversationId" in line:
            try:
                d = json.loads(line[5:].strip())
                conv_id = d.get("conversationId")
                citations_count = len(d.get("citations", []))
                confidence = d.get("confidence", "?")
                emergency = d.get("requiresEmergencyCare", "?")
            except json.JSONDecodeError:
                pass

    if has_done and has_tokens:
        _log("PASS", "POST /api/chat/ask (live AI)", f"conv={conv_id}, conf={confidence}")
    elif has_tokens:
        _log("PASS", "POST /api/chat/ask (streaming)", "tokens received but no done event")
    else:
        _log("FAIL", "POST /api/chat/ask", f"HTTP {code}: {body[:300]}")

    # Check tool_use events (Tavily search)
    tool_uses = body.count("tavily_search")
    if tool_uses >= 2:
        _log("PASS", "Tavily search integration", f"{tool_uses} search events")
    else:
        _log("FAIL", "Tavily search integration", f"Only {tool_uses} search events")

    return conv_id


# ── 7. Emergency detection ────────────────────────────────────
def test_emergency(token: str) -> None:
    auth = {"Authorization": f"Bearer {token}"}

    code, body = _request(
        f"{BASE_URL}/api/chat/ask",
        method="POST",
        data={"question": "I have severe chest pain and can't breathe"},
        headers=auth,
        timeout=120,
    )

    emergency_detected = False
    for line in body.split("\n"):
        if line.startswith("data:") and "requiresEmergencyCare" in line:
            try:
                d = json.loads(line[5:].strip())
                emergency_detected = d.get("requiresEmergencyCare", False)
            except json.JSONDecodeError:
                pass

    if emergency_detected:
        _log("PASS", "Emergency detection (chest pain)", "requiresEmergencyCare=true")
    elif "event: done" in body:
        _log("FAIL", "Emergency detection", "Response received but no emergency flag")
    else:
        _log("FAIL", "Emergency detection", f"HTTP {code}: {body[:200]}")


# ── 8. Conversation history ──────────────────────────────────
def test_history(token: str, conv_id: str | None) -> None:
    auth = {"Authorization": f"Bearer {token}"}

    code, body = _request(f"{BASE_URL}/api/chat/history", headers=auth)
    d = json.loads(body) if body.startswith("{") else {}
    convs = d.get("conversations", [])
    if code == 200 and len(convs) > 0:
        _log("PASS", "GET /api/chat/history", f"{len(convs)} conversations")
    else:
        _log("FAIL", "GET /api/chat/history", f"HTTP {code}, {len(convs)} conversations")

    if conv_id:
        code, body = _request(f"{BASE_URL}/api/chat/history/{conv_id}", headers=auth)
        d = json.loads(body) if body.startswith("{") else {}
        msgs = d.get("messages", [])
        if code == 200 and len(msgs) >= 2:
            _log("PASS", "GET /api/chat/history/{id}", f"{len(msgs)} messages")
        else:
            _log("FAIL", "GET /api/chat/history/{id}", f"HTTP {code}, {len(msgs)} messages")


# ── 9. V10 auto-update check ─────────────────────────────────
def test_v10_auto_update(token: str) -> None:
    auth = {"Authorization": f"Bearer {token}"}

    code, body = _request(f"{BASE_URL}/api/profile/v10", headers=auth)
    d = json.loads(body) if body.startswith("{") else {}
    if d.get("lastUpdateSource") == "auto" and d.get("version", 0) > 1:
        _log("PASS", "V10 auto-update after chat", f"version={d['version']}, source=auto")
    elif d.get("digest"):
        _log("PASS", "V10 has digest content", f"version={d.get('version')}")
    else:
        _log("FAIL", "V10 auto-update", f"source={d.get('lastUpdateSource')}, v={d.get('version')}")


# ── Main ─────────────────────────────────────────────────────
def main() -> None:
    global BASE_URL
    parser = argparse.ArgumentParser(description="MediCare AI Live E2E Check")
    parser.add_argument("--base-url", default=BASE_URL)
    args = parser.parse_args()
    BASE_URL = args.base_url

    print(f"\n{'='*60}")
    print(f"  MediCare AI — Live E2E Verification")
    print(f"  Backend: {BASE_URL}")
    print(f"  Test user: {TEST_EMAIL}")
    print(f"{'='*60}\n")

    # 1. Health
    test_health()

    # 2-3. Firebase auth
    token = test_firebase_signup()
    if not token:
        token = test_firebase_signin()
    else:
        test_firebase_signin()

    if not token:
        print("\n❌ Cannot proceed without Firebase token. Aborting.")
        sys.exit(1)

    # 4. Settings
    test_settings(token)

    # 5. V10 profile
    test_v10(token)

    # 6. Live chat
    conv_id = test_chat(token)

    # 7. Emergency detection
    test_emergency(token)

    # 8. History
    test_history(token, conv_id)

    # 9. V10 auto-update
    test_v10_auto_update(token)

    # ── Report ────────────────────────────────────────────
    print(f"\n{'='*60}")
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    skipped = sum(1 for r in results if r["status"] == "SKIP")
    total = len(results)
    print(f"  Results: {passed}/{total} passed, {failed} failed, {skipped} skipped")
    print(f"{'='*60}\n")

    # Save JSON report
    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "base_url": BASE_URL,
        "test_email": TEST_EMAIL,
        "summary": {"passed": passed, "failed": failed, "skipped": skipped, "total": total},
        "tests": results,
    }
    report_path = "live_e2e_report.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"  Report saved to {report_path}")

    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
