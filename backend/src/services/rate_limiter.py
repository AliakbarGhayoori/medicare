from __future__ import annotations

from collections import defaultdict
from time import time

_buckets: dict[str, list[float]] = defaultdict(list)


def check_rate_limit(key: str, max_requests: int, window_seconds: int) -> bool:
    allowed, _ = check_rate_limit_with_retry(key, max_requests, window_seconds)
    return allowed


def check_rate_limit_with_retry(
    key: str,
    max_requests: int,
    window_seconds: int,
) -> tuple[bool, int]:
    now = time()
    window = _buckets[key]
    _buckets[key] = [ts for ts in window if now - ts < window_seconds]
    if len(_buckets[key]) >= max_requests:
        oldest = min(_buckets[key]) if _buckets[key] else now
        retry_after = max(1, int(window_seconds - (now - oldest)))
        return False, retry_after
    _buckets[key].append(now)
    return True, 0
