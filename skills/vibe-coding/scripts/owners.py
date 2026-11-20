#!/usr/bin/env python3
"""Write-set ownership for hosts where several sessions share ONE checkout (Workspace mode
`shared-local`, see references/workspace-contract.md §10).

Each session declares what it is about to write; before editing, moving or committing it checks
the declarations of the others. Declarations are local machine state, never committed:

    <host>/.sdd/owners/<owner>.tsv      one line per entry: <entry>\t<since ISO>\t<spec or ->\t<note>

An entry is `path/to/file`, `path/to/file::symbol`, or a directory ending in `/` (covers every
file under it). Two entries collide when they name the same file and either side names no symbol
or both name the same symbol, or when one is a directory containing the other.

Commands (exit 0 ok · 1 collision / guard failed · 2 usage):
    owners.py claim   <host> --owner ID [--spec ID] [--note TEXT] ENTRY...
    owners.py release <host> --owner ID [ENTRY...]          (no entries = release everything)
    owners.py check   <host> --owner ID ENTRY...            collisions with OTHER owners' entries
    owners.py list    <host>
    owners.py commit-guard <host> --owner ID [--allow PATH...]
        Run right before `git commit`. Fails when the index holds a path that is neither in this
        owner's declaration nor in --allow (another session staged it — the shared index), or a
        staged path that another owner has declared.

Entries older than --stale-hours (default 12) are reported as stale and do not block.
"""
from __future__ import annotations

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path


def owners_dir(host: Path) -> Path:
    return host / ".sdd" / "owners"


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def load(host: Path) -> dict[str, list[tuple[str, str, str, str]]]:
    out: dict[str, list[tuple[str, str, str, str]]] = {}
    d = owners_dir(host)
    if not d.is_dir():
        return out
    for f in sorted(d.glob("*.tsv")):
        rows = []
        for line in f.read_text(encoding="utf-8").splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            parts = (line.split("\t") + ["", "", "", ""])[:4]
            rows.append(tuple(parts))
        out[f.stem] = rows
    return out


def save(host: Path, owner: str, rows) -> None:
    d = owners_dir(host)
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{owner}.tsv"
    if rows:
        p.write_text("".join("\t".join(r) + "\n" for r in rows), encoding="utf-8")
    elif p.exists():
        p.unlink()


def collide(a: str, b: str) -> bool:
    fa, _, sa = a.partition("::")
    fb, _, sb = b.partition("::")
    if fa.endswith("/") or fb.endswith("/"):
        da, db = fa if fa.endswith("/") else None, fb if fb.endswith("/") else None
        if da and db:
            return da.startswith(db) or db.startswith(da)
        d, f = (da, fb) if da else (db, fa)
        return f.startswith(d)
    return fa == fb and (not sa or not sb or sa == sb)


def is_stale(since: str, hours: float) -> bool:
    try:
        t = dt.datetime.fromisoformat(since)
    except ValueError:
        return False
    return (dt.datetime.now(dt.timezone.utc) - t).total_seconds() > hours * 3600


def collisions(host: Path, owner: str, entries: list[str], hours: float):
    hits, stale = [], []
    for other, rows in load(host).items():
        if other == owner:
            continue
        for entry, since, spec, note in rows:
            for e in entries:
                if collide(e, entry):
                    (stale if is_stale(since, hours) else hits).append((e, other, entry, since, spec))
    return hits, stale


def report(hits, stale) -> None:
    for e, other, entry, since, spec in stale:
        print(f"owners: STALE  {e} ~ {other}:{entry} (since {since}; >stale window — confirm with that session, then it may release)")
    for e, other, entry, since, spec in hits:
        print(f"owners: CONFLICT {e} ~ {other}:{entry} (since {since}, spec {spec or '-'})", file=sys.stderr)


def staged_paths(host: Path) -> list[str]:
    out = subprocess.run(["git", "-C", str(host), "diff", "--cached", "--name-only", "-z", "--no-renames"],
                         capture_output=True, check=True).stdout.decode()
    return [p for p in out.split("\0") if p]


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="shared-local write-set ownership", add_help=True)
    ap.add_argument("cmd", choices=["claim", "release", "check", "list", "commit-guard"])
    ap.add_argument("host")
    ap.add_argument("--owner")
    ap.add_argument("--spec", default="-")
    ap.add_argument("--note", default="")
    ap.add_argument("--allow", nargs="*", default=[])
    ap.add_argument("--stale-hours", type=float, default=12.0)
    ap.add_argument("entries", nargs="*")
    a = ap.parse_args(argv)
    host = Path(a.host).resolve()
    if a.cmd != "list" and not a.owner:
        print("owners: --owner is required", file=sys.stderr)
        return 2
    if a.owner and ("/" in a.owner or a.owner.startswith(".")):
        print("owners: --owner must be a plain name", file=sys.stderr)
        return 2
    data = load(host)

    if a.cmd == "list":
        for owner, rows in data.items():
            for entry, since, spec, note in rows:
                flag = " (stale)" if is_stale(since, a.stale_hours) else ""
                print(f"{owner}\t{entry}\t{since}{flag}\t{spec}\t{note}")
        return 0

    if a.cmd in ("claim", "check") and not a.entries:
        print(f"owners: {a.cmd} needs at least one entry", file=sys.stderr)
        return 2

    if a.cmd == "check":
        hits, stale = collisions(host, a.owner, a.entries, a.stale_hours)
        report(hits, stale)
        return 1 if hits else 0

    if a.cmd == "claim":
        hits, stale = collisions(host, a.owner, a.entries, a.stale_hours)
        report(hits, stale)
        if hits:
            print("owners: claim refused — serialise with that session (same lane) or narrow to file::symbol", file=sys.stderr)
            return 1
        rows = data.get(a.owner, [])
        have = {r[0] for r in rows}
        rows += [(e, now(), a.spec, a.note) for e in a.entries if e not in have]
        save(host, a.owner, rows)
        print(f"owners: {a.owner} holds {len(rows)} entr{'y' if len(rows) == 1 else 'ies'}")
        return 0

    if a.cmd == "release":
        rows = data.get(a.owner, [])
        keep = [r for r in rows if a.entries and r[0] not in a.entries]
        save(host, a.owner, keep)
        print(f"owners: {a.owner} released {len(rows) - len(keep)}, holds {len(keep)}")
        return 0

    # commit-guard
    mine = [r[0] for r in data.get(a.owner, [])] + list(a.allow)
    bad_foreign, bad_claimed = [], []
    for p in staged_paths(host):
        if not any(collide(p, m) for m in mine):
            bad_foreign.append(p)
        hits, _ = collisions(host, a.owner, [p], a.stale_hours)
        if hits:
            bad_claimed.append((p, hits[0][1]))
    for p in bad_foreign:
        print(f"owners: STAGED BUT NOT YOURS  {p}  (declare it, pass --allow, or leave it to the session that staged it)", file=sys.stderr)
    for p, other in bad_claimed:
        print(f"owners: STAGED BUT DECLARED BY {other}  {p}", file=sys.stderr)
    if bad_foreign or bad_claimed:
        print("owners: commit-guard FAILED — do not commit; restore only your paths (see workspace-contract §10)", file=sys.stderr)
        return 1
    print("owners: commit-guard ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
