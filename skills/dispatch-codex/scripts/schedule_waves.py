#!/usr/bin/env python3
"""Schedule edit-waves / verify-waves from a dispatch graph.

Usage:
  python3 schedule_waves.py <graph.json>
  python3 schedule_waves.py --host HOST --spec ID
  python3 pack_dispatch_units.py HOST SPEC | python3 schedule_waves.py -

Exit: 0 ok, 1 incomplete graph, 2 usage.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def edit_conflict(a: dict, b: dict) -> bool:
    aw, ar = set(a.get("writes") or []), set(a.get("reads") or [])
    bw, br = set(b.get("writes") or []), set(b.get("reads") or [])
    if aw & bw:
        return True
    if aw & br or bw & ar:
        return True
    a_deps = set(a.get("depends_on_units") or [])
    b_deps = set(b.get("depends_on_units") or [])
    if a["id"] in b_deps or b["id"] in a_deps:
        return True
    return False


def verify_conflict(a: dict, b: dict) -> bool:
    ca, cb = set(a.get("claims") or []), set(b.get("claims") or [])
    if ca & cb:
        return True
    return False


def _ready(units: list[dict], done: set[str]) -> list[dict]:
    out = []
    for u in units:
        if u["id"] in done:
            continue
        deps = set(u.get("depends_on_units") or [])
        if deps <= done:
            out.append(u)
    return out


def _bin_parallel(ready: list[dict], conflict_fn, max_n: int) -> list[dict]:
    wave: list[dict] = []
    for u in ready:
        if len(wave) >= max_n:
            break
        if any(conflict_fn(u, x) for x in wave):
            continue
        wave.append(u)
    if not wave and ready:
        wave = [ready[0]]
    return wave


def schedule(graph: dict, edit_parallel: int = 2, verify_parallel: int = 4) -> dict:
    units = list(graph.get("units") or [])
    edit_parallel = max(1, min(4, int(edit_parallel)))
    verify_parallel = max(1, min(8, int(verify_parallel)))

    edit_waves: list[list[str]] = []
    done: set[str] = set()
    guard = 0
    while len(done) < len(units) and guard < 64:
        guard += 1
        ready = _ready(units, done)
        if not ready:
            leftover = [u["id"] for u in units if u["id"] not in done]
            return {
                "spec_id": graph.get("spec_id"),
                "error": "cyclic_or_unresolved_deps",
                "leftover": leftover,
                "edit_waves": edit_waves,
                "verify_waves": [],
            }
        wave = _bin_parallel(ready, edit_conflict, edit_parallel)
        edit_waves.append([u["id"] for u in wave])
        done.update(u["id"] for u in wave)

    # Verify waves: same DAG order, but bin by verify lock; lab claims serialize
    verify_waves: list[list[str]] = []
    vdone: set[str] = set()
    by_id = {u["id"]: u for u in units}
    guard = 0
    while len(vdone) < len(units) and guard < 64:
        guard += 1
        # verify-ready = edit-complete (all units already edited in this offline schedule)
        remaining = [by_id[i] for i in sum(edit_waves, []) if i not in vdone]
        # preserve edit order: only units whose edit-wave index <= current progress
        wave = _bin_parallel(remaining, verify_conflict, verify_parallel)
        verify_waves.append([u["id"] for u in wave])
        vdone.update(u["id"] for u in wave)

    return {
        "spec_id": graph.get("spec_id"),
        "edit_parallel": edit_parallel,
        "verify_parallel": verify_parallel,
        "edit_waves": edit_waves,
        "verify_waves": verify_waves,
        "too_large": graph.get("too_large") or [],
        "incomplete_allowlist": graph.get("incomplete_allowlist") or [],
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("graph", nargs="?", help="graph JSON file or - for stdin")
    ap.add_argument("--host")
    ap.add_argument("--spec")
    ap.add_argument("--edit-parallel", type=int, default=2)
    ap.add_argument("--verify-parallel", type=int, default=4)
    args = ap.parse_args()

    if args.host and args.spec:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import pack_dispatch_units as pack

        graph = pack.pack_units(Path(args.host).resolve(), args.spec)
    elif args.graph == "-" or (args.graph is None and not sys.stdin.isatty()):
        graph = json.load(sys.stdin)
    elif args.graph:
        graph = json.loads(Path(args.graph).read_text(encoding="utf-8"))
    else:
        print("schedule_waves: need graph.json or --host/--spec", file=sys.stderr)
        raise SystemExit(2)

    out = schedule(graph, edit_parallel=args.edit_parallel, verify_parallel=args.verify_parallel)
    print(json.dumps(out, ensure_ascii=False, indent=2))
    if out.get("error"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
