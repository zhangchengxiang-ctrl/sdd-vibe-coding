"""Event ingest — STUB: always 204. Codex must reject malformed events with 400."""


def ingest(event: dict) -> dict:
    _ = event
    return {"status": 204}
