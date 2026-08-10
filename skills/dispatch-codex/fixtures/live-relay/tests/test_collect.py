import json

from svc.ingest.collect import ingest


def test_valid_event_204():
    got = ingest({"type": "click", "payload": {"x": 1}})
    assert got["status"] == 204


def test_missing_type_400():
    got = ingest({"payload": {"x": 1}})
    assert got["status"] == 400
    assert got.get("code") == "bad_event"


def test_empty_type_400():
    got = ingest({"type": "", "payload": {}})
    assert got["status"] == 400
    assert got.get("code") == "bad_event"


def test_payload_not_dict_400():
    got = ingest({"type": "click", "payload": ["nope"]})
    assert got["status"] == 400
    assert got.get("code") == "bad_event"


def test_oversized_event_400():
    huge = {"type": "blob", "payload": {"d": "x" * 9000}}
    assert len(json.dumps(huge)) > 8192
    got = ingest(huge)
    assert got["status"] == 400
    assert got.get("code") == "too_large"
