from svc.auth.rate import check


def test_allows_up_to_limit():
    store: dict = {}
    now = 1_700_000_000
    for i in range(3):
        got = check("tok-a", now=now + i, window=10, limit=3, store=store)
        assert got["limited"] is False, i
        assert got["remaining"] == 3 - (i + 1)


def test_fourth_is_limited():
    store: dict = {}
    now = 1_700_000_010
    for _ in range(3):
        check("tok-b", now=now, window=10, limit=3, store=store)
    got = check("tok-b", now=now + 1, window=10, limit=3, store=store)
    assert got["limited"] is True
    assert got["remaining"] == 0


def test_window_expiry_resets():
    store: dict = {}
    now = 1_700_000_100
    for _ in range(3):
        check("tok-c", now=now, window=10, limit=3, store=store)
    got = check("tok-c", now=now + 11, window=10, limit=3, store=store)
    assert got["limited"] is False
    assert got["remaining"] == 2


def test_tokens_isolated():
    store: dict = {}
    now = 1_700_000_200
    for _ in range(3):
        check("tok-d", now=now, window=10, limit=3, store=store)
    got = check("tok-e", now=now, window=10, limit=3, store=store)
    assert got["limited"] is False
