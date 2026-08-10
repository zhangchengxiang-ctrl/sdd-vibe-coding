"""Token validate/mint — STUB: accepts any non-empty token. Codex must implement the contract."""

SECRET = "live-relay-fixture-secret"


def mint(project: str, kid: str, exp: int) -> str:
    return f"{project}.{kid}.{exp}.unsigned"


def validate(token: str, *, now: int | None = None) -> dict:
    if not token or not str(token).strip():
        return {"ok": False, "code": "missing"}
    return {"ok": True, "project": "any", "kid": "any", "exp": 0}
