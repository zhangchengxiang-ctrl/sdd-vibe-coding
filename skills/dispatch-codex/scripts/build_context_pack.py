#!/usr/bin/env python3
"""Build an Outcome-first Context Pack prompt for one Spec longitudinal slice.

Usage:
  python3 build_context_pack.py <host-root> <spec-id> <slice-id>
  python3 build_context_pack.py <host-root> <spec-id> --list
  python3 build_context_pack.py <host-root> <spec-id> S1 --json

Exit: 0 ok, 1 not found / incomplete, 2 usage.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

T_ID_RE = re.compile(r"T-\d+", re.I)
PATHISH_RE = re.compile(
    r"(?:^|[\s,;，、])([A-Za-z0-9_./@-]+\.[A-Za-z0-9]+|[A-Za-z0-9_./-]+/[A-Za-z0-9_./-]+)"
)


def die(msg: str, code: int = 1) -> None:
    print(f"build_context_pack: {msg}", file=sys.stderr)
    raise SystemExit(code)


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def resolve_sdd_root(host: Path) -> Path:
    agents = host / "AGENTS.md"
    if agents.is_file():
        for line in agents.read_text(encoding="utf-8").splitlines():
            m = re.match(r"-\s*SDD docs root:\s*(.+)$", line.strip())
            if m:
                rel = m.group(1).strip().strip("`")
                root = (host / rel).resolve()
                if root.is_dir():
                    return root
    for cand in (host / "docs", host / "docs" / "sdd"):
        if (cand / "specs").is_dir():
            return cand.resolve()
    return (host / "docs").resolve()


def find_slice_table(plan_text: str) -> list[dict[str, str]]:
    """Parse longitudinal slice markdown table(s)."""
    lines = plan_text.splitlines()
    rows: list[dict[str, str]] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if "切片" not in line or "|" not in line:
            i += 1
            continue
        header = cells(line)
        header_l = [h.lower() for h in header]
        if not any("切片" in h for h in header):
            i += 1
            continue
        # skip separator
        i += 1
        if i < len(lines) and re.match(r"^\s*\|?\s*[-:| ]+\|", lines[i]):
            i += 1

        def col(*names: str) -> int | None:
            for n in names:
                for idx, h in enumerate(header):
                    if n in h.replace(" ", ""):
                        return idx
                for idx, h in enumerate(header_l):
                    if n.lower() in h.replace(" ", ""):
                        return idx
            return None

        # fuzzy: 切片 ID / 入口 / 完成定义 / 触及路径 / 依赖 / 备注
        idx_id = col("切片ID", "切片id", "切片")
        idx_entry = col("入口")
        idx_done = col("完成定义", "完成")
        idx_paths = col("触及路径", "路径")
        idx_dep = col("依赖")
        idx_note = col("备注")
        if idx_id is None:
            i += 1
            continue

        while i < len(lines) and "|" in lines[i] and not lines[i].strip().startswith("#"):
            if re.match(r"^\s*\|?\s*[-:| ]+\|", lines[i]):
                i += 1
                continue
            c = cells(lines[i])
            i += 1
            if len(c) <= idx_id:
                continue
            sid = c[idx_id].strip()
            if not sid or sid.startswith("-") or sid.lower() in {"切片 id", "切片id"}:
                continue
            if not re.match(r"^S\d+$", sid, re.I) and not re.match(
                r"^[A-Za-z][\w.-]*$", sid
            ):
                # still accept S1-style or free ids
                if "T-" in sid:
                    continue

            def get(idx: int | None) -> str:
                if idx is None or idx >= len(c):
                    return ""
                return c[idx].strip()

            rows.append(
                {
                    "slice_id": sid,
                    "entry": get(idx_entry),
                    "done_def": get(idx_done),
                    "paths_raw": get(idx_paths),
                    "deps": get(idx_dep),
                    "note": get(idx_note),
                }
            )
        break
    return rows


def extract_t_ids(text: str) -> list[str]:
    """Extract T-xxx ids; expand inclusive ranges like T-005–T-008 or T-005-T-008."""
    if not text:
        return []
    out: list[str] = []
    seen: set[str] = set()

    def add(num_str: str) -> None:
        u = f"T-{num_str}"
        key = u.upper()
        if key not in seen:
            seen.add(key)
            out.append(u)

    for m in re.finditer(r"T-(\d+)\s*[–—~～\-]\s*T-(\d+)", text, re.I):
        a, b = int(m.group(1)), int(m.group(2))
        lo, hi = (a, b) if a <= b else (b, a)
        w = len(m.group(1))
        for n in range(lo, hi + 1):
            add(f"{n:0{w}d}")

    stripped = re.sub(r"T-\d+\s*[–—~～\-]\s*T-\d+", " ", text, flags=re.I)
    for m in re.finditer(r"T-(\d+)", stripped, re.I):
        add(m.group(1))
    return out


def extract_paths(paths_raw: str, note: str) -> list[str]:
    blob = paths_raw or ""
    if not blob and note:
        m = re.search(r"paths?\s*[:=：]\s*(.+)$", note, re.I | re.M)
        if m:
            blob = m.group(1)
        else:
            blob = note
    paths: list[str] = []
    for part in re.split(r"[,;，、\s]+", blob):
        p = part.strip().strip("`")
        if not p or p in {"—", "-", "n/a", "N/A"}:
            continue
        if "/" in p or re.search(r"\.\w{1,8}$", p):
            if p not in paths:
                paths.append(p)
    return paths[:12]


def rel_spec_files(sdd_root: Path, host: Path, spec_id: str) -> list[str]:
    spec_dir = sdd_root / "specs" / spec_id
    files = []
    for name in ("VERSION.md", "contract.md", "tests.md", "plan.md", "run.md"):
        p = spec_dir / name
        if p.is_file():
            try:
                files.append(str(p.relative_to(host)))
            except ValueError:
                files.append(str(p))
    return files


def build_pack(
    host: Path,
    spec_id: str,
    slice_id: str,
    row: dict[str, str],
) -> dict:
    sdd = resolve_sdd_root(host)
    t_ids = extract_t_ids(row.get("done_def", ""))
    paths = extract_paths(row.get("paths_raw", ""), row.get("note", ""))
    pointers = rel_spec_files(sdd, host, spec_id)
    entry = row.get("entry") or "(见 plan.md 本片入口)"
    goal = f"完成切片 {slice_id}：{entry}"
    if t_ids:
        goal += f"（Oracle：{', '.join(t_ids)}）"

    return {
        "slice_id": slice_id,
        "spec_id": spec_id,
        "goal": goal,
        "entry": entry,
        "t_ids": t_ids,
        "paths": paths,
        "pointers": pointers,
        "deps": row.get("deps", ""),
        "done_def": row.get("done_def", ""),
    }


def render_prompt(pack: dict, docs_hint: str) -> str:
    t_ids = ", ".join(pack["t_ids"]) if pack["t_ids"] else "(见 plan.md 本片完成定义)"
    paths = "\n".join(f"  - {p}" for p in pack["paths"]) if pack["paths"] else "  - (未声明触及路径；按 contract 事实映射自行定位，勿扩大范围)"
    pointers = "\n".join(f"  - {p}" for p in pack["pointers"]) if pack["pointers"] else f"  - {docs_hint}/specs/{pack['spec_id']}/"

    return f"""SLICE_ID={pack['slice_id']}
SPEC_ID={pack['spec_id']}

## Goal
{pack['goal']}
只做这一片；禁止顺手做其他切片或重构无关模块。

## Context
Spec pointers (read from disk; do not expect full text in this prompt):
{pointers}
Suggested paths for this slice:
{paths}
Oracle ids: {t_ids}
Deps: {pack['deps'] or 'n/a'}

## Constraints
- Follow host AGENTS.md and vibe-coding quality bars **except** mid-flow human approval: this Pack is already authorized via CLI (`approval_policy=never`). Do NOT wait for 批准 / ask clarifying questions / use doc-coauthoring.
- Diff must stay within this slice; respect Out of Scope in contract.md.
- Do NOT modify tests.md or product acceptance-matrix Oracle (钉 2).
- UI changes: read plugin design-standards LOAD-MAP first; note refinement|redesign if touching existing UI.
- Prefer reading files via tools over assuming prompt pasted the codebase.
- Final message: short status + evidence only — zero questions.

## Done when
- Behavior for {t_ids} is implemented and observable.
- Run the slice-relevant checks/tests; write results to run.md with oracle-freeze: intact and 红绿证据 (or N/A · reason).
- Short report only: what shipped, evidence paths, next slice id — no "可交付".

按 vibe-coding Build 本切片；对照 contract 事实映射再改。
"""


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("host")
    ap.add_argument("spec_id")
    ap.add_argument("slice_id", nargs="?")
    ap.add_argument("--list", action="store_true", help="list slice ids from plan.md")
    ap.add_argument("--json", action="store_true", help="emit pack as JSON")
    args = ap.parse_args()

    host = Path(args.host).resolve()
    if not host.is_dir():
        die(f"host not a directory: {host}", 2)

    sdd = resolve_sdd_root(host)
    plan_path = sdd / "specs" / args.spec_id / "plan.md"
    if not plan_path.is_file():
        die(f"plan.md not found: {plan_path}")

    rows = find_slice_table(plan_path.read_text(encoding="utf-8"))
    if not rows:
        die(f"no longitudinal slice table found in {plan_path}")

    if args.list:
        for r in rows:
            print(r["slice_id"])
        return

    if not args.slice_id:
        die("slice_id required (or pass --list)", 2)

    # normalize S1 vs s1
    want = args.slice_id.strip()
    row = next((r for r in rows if r["slice_id"].lower() == want.lower()), None)
    if row is None:
        known = ", ".join(r["slice_id"] for r in rows)
        die(f"slice '{want}' not in plan.md (have: {known})")

    pack = build_pack(host, args.spec_id, row["slice_id"], row)
    if not pack["t_ids"]:
        print(
            "build_context_pack: WARN no T-xxx in 完成定义 — pack still emitted",
            file=sys.stderr,
        )

    if args.json:
        print(json.dumps(pack, ensure_ascii=False, indent=2))
        return

    try:
        docs_hint = str(sdd.relative_to(host))
    except ValueError:
        docs_hint = str(sdd)
    print(render_prompt(pack, docs_hint))


if __name__ == "__main__":
    main()
