import hashlib
import time

from svc.auth.token import SECRET
from svc.gateway import handle


def _token(project="projA", kid="k1", exp=None):
    exp = int(time.time()) + 3600 if exp is None else exp
    mac = hashlib.sha256(f"{project}.{kid}.{exp}.{SECRET}".encode()).hexdigest()[:16]
    return f"{project}.{kid}.{exp}.{mac}"


def test_gateway_ok_204():
    store: dict = {}
    got = handle(_token(), {"type": "click", "payload": {"x": 1}}, now=int(time.time()), store=store)
    assert got["status"] == 204


def test_gateway_bad_token_401():
    got = handle("not-a-token", {"type": "click", "payload": {}}, now=int(time.time()), store={})
    assert got["status"] == 401


def test_gateway_expired_401():
    got = handle(_token(exp=int(time.time()) - 5), {"type": "click", "payload": {}}, now=int(time.time()), store={})
    assert got["status"] == 401


def test_gateway_rate_limited_429():
    store: dict = {}
    tok = _token()
    now = int(time.time())
    event = {"type": "click", "payload": {"n": 1}}
    for _ in range(3):
        assert handle(tok, event, now=now, store=store)["status"] == 204
    got = handle(tok, event, now=now + 1, store=store)
    assert got["status"] == 429


def test_gateway_bad_event_400():
    got = handle(_token(), {"payload": {}}, now=int(time.time()), store={})
    assert got["status"] == 400
