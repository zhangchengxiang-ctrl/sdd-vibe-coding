#!/usr/bin/env python3
"""Pack acceptance slices (A) into Codex dispatch units (D) under a 272K window.

Usage:
  python3 pack_dispatch_units.py <host> <spec-id> [--json]
  python3 pack_dispatch_units.py <host> <spec-id> --slice S1
  python3 pack_dispatch_units.py <host> <spec-id> --list

Exit: 0 ok, 1 incomplete / too-large policy, 2 usage.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import build_context_pack as bcp  # noqa: E402

CHATTER = 3
COMPACT_LIMIT = 180_000
BASELINE_DEFAULT = 40_000
PACK_OVERHEAD = 2_000
TEST_LOG_BUDGET = 8_000
MISSING_FILE_TOKENS = 500


def read_baseline(host: Path) -> int:
    agents = host / "AGENTS.md"
    if agents.is_file():
        text = agents.read_text(encoding="utf-8", errors="replace")
        m = re.search(
            r"Codex harness baseline tokens:\s*(\d+)", text, re.I
        )
        if m:
            return int(m.group(1))
    return BASELINE_DEFAULT


def parse_oracle_kind(note: str, extra: str = "") -> str:
    blob = f"{note} {extra}"
    m = re.search(r"oracle(?:_kind)?\s*[:=]\s*(\w+)", blob, re.I)
    if m:
        k = m.group(1).lower()
        if k in {"unit", "machine", "lab", "human", "integration"}:
            return "unit" if k == "integration" else k
    if re.search(r"\b(lab|kind|k8s|kubernetes|browser|ux|ui)\b", blob, re.I):
        if re.search(r"\b(browser|ux|\bui\b)\b", blob, re.I):
            return "human"
        return "lab"
    return "machine"


def parse_claims(note: str, extra: str = "") -> list[str]:
    blob = f"{note} {extra}"
    m = re.search(r"claims?\s*[:=]\s*([^\n|]+)", blob, re.I)
    if not m:
        return []
    parts = re.split(r"[,;，、\s]+", m.group(1).strip())
    return [p.strip() for p in parts if p.strip() and p.strip() not in {"—", "-", "n/a", "N/A"}]


def parse_deps(deps_raw: str, spec_id: str) -> list[str]:
    """Machine-readable deps: S2 or other-spec:S1. Free text is ignored as a hard edge."""
    out: list[str] = []
    if not deps_raw:
        return out
    for part in re.split(r"[,;，、|/]+", deps_raw):
        p = part.strip()
        if not p or p.lower() in {"—", "-", "无", "n/a"}:
            continue
        m = re.match(r"^S(\d+)$", p, re.I)
        if m:
            out.append(f"{spec_id}:S{m.group(1)}")
            continue
        m = re.match(r"^([\w.-]+):S(\d+)$", p, re.I)
        if m:
            out.append(f"{m.group(1)}:S{m.group(2)}")
    return out


def estimate_path_tokens(host: Path, rel: str) -> int:
    fp = host / rel
    try:
        if fp.is_file():
            size = fp.stat().st_size
            if size > 800_000:
                return 200_000
            return max(1, size // 4)
        if fp.is_dir():
            total = 0
            n = 0
            for f in fp.rglob("*"):
                if not f.is_file():
                    continue
                sz = f.stat().st_size
                if sz > 500_000:
                    continue
                total += sz // 4
                n += 1
                if n >= 40 or total > 200_000:
                    break
            return total or MISSING_FILE_TOKENS
    except OSError:
        pass
    return MISSING_FILE_TOKENS


def estimate_unit_tokens(host: Path, paths: list[str], baseline: int) -> int:
    work = sum(estimate_path_tokens(host, p) for p in paths) if paths else MISSING_FILE_TOKENS
    return baseline + PACK_OVERHEAD + work * CHATTER + TEST_LOG_BUDGET


def _prefixes(paths: set[str]) -> set[str]:
    out: set[str] = set()
    for p in paths:
        parts = Path(p).parts
        for i in range(3, min(len(parts) + 1, 6)):
            out.add("/".join(parts[:i]))
    return out


def write_sets_related(a: set[str], b: set[str]) -> bool:
    if not a or not b:
        return False
    if a & b:
        return True
    for x in a:
        xs = x.rstrip("/") + "/"
        for y in b:
            ys = y.rstrip("/") + "/"
            if x.startswith(ys) or y.startswith(xs):
                return True
    return bool(_prefixes(a) & _prefixes(b))


def slice_records(host: Path, spec_id: str) -> list[dict]:
    sdd = bcp.resolve_sdd_root(host)
    plan_path = sdd / "specs" / spec_id / "plan.md"
    if not plan_path.is_file():
        raise SystemExit(f"pack_dispatch_units: plan.md not found: {plan_path}")
    rows = bcp.find_slice_table(plan_path.read_text(encoding="utf-8"))
    if not rows:
        raise SystemExit(f"pack_dispatch_units: no slice table in {plan_path}")
    recs = []
    for r in rows:
        paths = bcp.extract_paths(r.get("paths_raw", ""), r.get("note", ""))
        note = r.get("note", "")
        oracle_kind = parse_oracle_kind(note)
        claims = parse_claims(note)
        if oracle_kind == "lab" and not claims:
            claims = ["lab:default"]
        recs.append(
            {
                "slice_id": r["slice_id"],
                "spec_id": spec_id,
                "entry": r.get("entry", ""),
                "t_ids": bcp.extract_t_ids(r.get("done_def", "")),
                "paths": paths,
                "deps_raw": r.get("deps", ""),
                "depends_on": parse_deps(r.get("deps", ""), spec_id),
                "note": note,
                "oracle_kind": oracle_kind,
                "claims": claims,
            }
        )
    return recs


def _sid(spec_id: str, slice_id: str) -> str:
    m = re.match(r"^S(\d+)$", slice_id, re.I)
    return f"{spec_id}:S{m.group(1)}" if m else f"{spec_id}:{slice_id}"


def pack_units(host: Path, spec_id: str, baseline: int | None = None) -> dict:
    baseline = read_baseline(host) if baseline is None else baseline
    recs = slice_records(host, spec_id)
    units: list[dict] = []
    current: dict | None = None

    def new_unit(rec: dict, est: int, too_large: bool) -> dict:
        n = len(units) + (0 if current is None else 1) + 1
        return {
            "id": f"D{n}",
            "spec_id": spec_id,
            "slices": [rec["slice_id"]],
            "t_ids": list(rec["t_ids"]),
            "writes": list(rec["paths"]),
            "reads": list(rec["paths"]),
            "depends_on_slices": list(rec["depends_on"]),
            "oracle_kind": rec["oracle_kind"],
            "claims": list(rec["claims"]),
            "est_tokens": est,
            "too_large": too_large,
            "compact_limit": COMPACT_LIMIT,
            "baseline": baseline,
        }

    def merge_into(unit: dict, rec: dict, est: int) -> None:
        unit["slices"].append(rec["slice_id"])
        for t in rec["t_ids"]:
            if t not in unit["t_ids"]:
                unit["t_ids"].append(t)
        for p in rec["paths"]:
            if p not in unit["writes"]:
                unit["writes"].append(p)
                unit["reads"].append(p)
        for d in rec["depends_on"]:
            if d not in unit["depends_on_slices"]:
                unit["depends_on_slices"].append(d)
        for c in rec["claims"]:
            if c not in unit["claims"]:
                unit["claims"].append(c)
        if rec["oracle_kind"] == "human" or (
            rec["oracle_kind"] == "lab" and unit["oracle_kind"] == "machine"
        ):
            unit["oracle_kind"] = rec["oracle_kind"]
        elif rec["oracle_kind"] == "lab" and unit["oracle_kind"] == "unit":
            unit["oracle_kind"] = "lab"
        unit["est_tokens"] = est

    def deps_ok(rec: dict, unit: dict) -> bool:
        in_unit = {_sid(spec_id, s) for s in unit["slices"]}
        for d in rec["depends_on"]:
            if d.startswith(f"{spec_id}:") and d not in in_unit:
                # dep on earlier slice not in this unit → cannot merge
                return False
        return True

    for rec in recs:
        writes = set(rec["paths"])
        est = estimate_unit_tokens(host, rec["paths"], baseline)
        if rec["paths"] and est > COMPACT_LIMIT:
            if current:
                units.append(current)
                current = None
            u = new_unit(rec, estimate_unit_tokens(host, rec["paths"], baseline), True)
            u["id"] = f"D{len(units) + 1}"
            units.append(u)
            continue
        if current is None:
            current = new_unit(rec, est, False)
            current["id"] = f"D{len(units) + 1}"
            continue
        combined_paths = list(dict.fromkeys(current["writes"] + rec["paths"]))
        combined_est = estimate_unit_tokens(host, combined_paths, baseline)
        can_merge = (
            combined_est <= COMPACT_LIMIT
            and write_sets_related(set(current["writes"]), writes)
            and deps_ok(rec, current)
            and rec["paths"]
            and current["writes"]
        )
        if can_merge:
            merge_into(current, rec, combined_est)
        else:
            units.append(current)
            current = new_unit(rec, est, False)
            current["id"] = f"D{len(units) + 1}"
    if current:
        units.append(current)

    # Renumber D1..Dn in order
    for i, u in enumerate(units, 1):
        u["id"] = f"D{i}"
        # depends_on_units: other Ds that contain a depended-on slice
        dep_units: list[str] = []
        my_slices = {_sid(spec_id, s) for s in u["slices"]}
        for d in u["depends_on_slices"]:
            if d in my_slices:
                continue
            for other in units:
                if other is u:
                    continue
                other_ids = {_sid(spec_id, s) for s in other["slices"]}
                if d in other_ids and other["id"] not in dep_units:
                    dep_units.append(other["id"])
        u["depends_on_units"] = dep_units
        u["allowlist_ok"] = bool(u["writes"])

    incomplete = [u["id"] for u in units if not u["allowlist_ok"]]
    too_large = [u["id"] for u in units if u["too_large"]]
    return {
        "spec_id": spec_id,
        "baseline": baseline,
        "compact_limit": COMPACT_LIMIT,
        "units": units,
        "incomplete_allowlist": incomplete,
        "too_large": too_large,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("host")
    ap.add_argument("spec_id")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--list", action="store_true", help="print unit ids and member slices")
    ap.add_argument("--slice", dest="slice_id", help="print unit containing this slice")
    ap.add_argument("--baseline", type=int, default=None)
    args = ap.parse_args()

    host = Path(args.host).resolve()
    if not host.is_dir():
        print(f"pack_dispatch_units: host not a directory: {host}", file=sys.stderr)
        raise SystemExit(2)

    graph = pack_units(host, args.spec_id, baseline=args.baseline)

    if args.slice_id:
        want = args.slice_id.strip()
        unit = next(
            (u for u in graph["units"] if any(s.lower() == want.lower() for s in u["slices"])),
            None,
        )
        if unit is None:
            print(f"pack_dispatch_units: slice {want} not in graph", file=sys.stderr)
            raise SystemExit(1)
        if args.json:
            print(json.dumps(unit, ensure_ascii=False, indent=2))
        else:
            print(f"{unit['id']}\t{','.join(unit['slices'])}")
        return

    if args.list:
        for u in graph["units"]:
            flags = []
            if u["too_large"]:
                flags.append("too_large")
            if not u["allowlist_ok"]:
                flags.append("no_allowlist")
            extra = f"\t{','.join(flags)}" if flags else ""
            print(f"{u['id']}\t{','.join(u['slices'])}\test={u['est_tokens']}{extra}")
        return

    print(json.dumps(graph, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
