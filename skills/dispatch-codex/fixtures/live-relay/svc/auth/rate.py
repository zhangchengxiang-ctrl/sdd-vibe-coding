"""Per-token rate limit — STUB: never limits. Codex must implement the contract."""


def check(token: str, *, now: int, window: int = 10, limit: int = 3, store: dict | None = None) -> dict:
    _ = (token, now, window, limit, store)
    return {"limited": False, "remaining": 99, "count": 0}
