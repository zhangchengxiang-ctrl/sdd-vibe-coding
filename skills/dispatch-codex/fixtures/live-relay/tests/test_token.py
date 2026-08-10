import hashlib
import time

from svc.auth.token import SECRET, mint, validate


def _mac(project: str, kid: str, exp: int) -> str:
    return hashlib.sha256(f"{project}.{kid}.{exp}.{SECRET}".encode()).hexdigest()[:16]


def test_valid_token_ok():
    exp = int(time.time()) + 3600
    token = f"projA.k1.{exp}.{_mac('projA', 'k1', exp)}"
    got = validate(token, now=int(time.time()))
    assert got["ok"] is True
    assert got["project"] == "projA"
    assert got["kid"] == "k1"
    assert got["exp"] == exp


def test_mint_roundtrip():
    exp = int(time.time()) + 60
    token = mint("p2", "kid9", exp)
    got = validate(token, now=int(time.time()))
    assert got["ok"] is True
    assert got["project"] == "p2"


def test_missing_token():
    assert validate("", now=1) == {"ok": False, "code": "missing"}
    assert validate("   ", now=1)["ok"] is False


def test_invalid_mac():
    exp = int(time.time()) + 3600
    token = f"projA.k1.{exp}.deadbeefdeadbeef"
    got = validate(token, now=int(time.time()))
    assert got == {"ok": False, "code": "invalid"}


def test_expired_token():
    exp = int(time.time()) - 10
    token = f"projA.k1.{exp}.{_mac('projA', 'k1', exp)}"
    got = validate(token, now=int(time.time()))
    assert got == {"ok": False, "code": "expired"}
