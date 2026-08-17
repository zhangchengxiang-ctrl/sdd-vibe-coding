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



def _load_check_spec():
    """The single definition of "is this command executable" lives in check_spec."""
    import importlib.util
    cs_path = Path(__file__).resolve().parents[2] / "spec" / "scripts" / "check_spec.py"
    spec = importlib.util.spec_from_file_location("cs_pack", cs_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def classify_oracles(sdd: Path, spec_id: str, t_ids: list[str]) -> list[dict[str, str]]:
    """Each T-id's Oracle, classified machine | human | invalid.

    The dispatch payload used to carry `Oracle ids: T-001, T-002` and let the
    implementer pick its own judge. Rendering a referential command ("同 T-001") into a
    block labelled "frozen Oracle, the runner replays this" would be a second lie of
    the same kind, so invalid ones stop the pack instead.
    """
    tests_path = sdd / "specs" / spec_id / "tests.md"
    if not tests_path.is_file() or not t_ids:
        return []
    try:
        cs = _load_check_spec()
    except Exception:
        return []
    bodies = cs.extract_test_bodies(tests_path.read_text(encoding="utf-8"))
    out = []
    for tid in t_ids:
        body = bodies.get(tid)
        if body is None:
            out.append({"id": tid, "cmd": "", "then": "", "kind": "invalid",
                        "why": f"no ## {tid} body in tests.md"})
            continue
        m = re.search(r"(?ms)^\s*#{2,4}\s+Then[^\n]*\n(.*?)(?=^\s*#{2,4}\s+|\Z)", body)
        then = " ".join((m.group(1) if m else "").split())[:260]
        raw = (cs.automation_command(body) or "").strip()
        bare = raw.strip("`").strip()
        if not bare:
            kind, why = "invalid", "no 自动化 `命令：` line"
        elif bare.lower() in cs.HUMAN_ORACLE:   # one definition, in check_spec
            kind, why = "human", ""
        elif cs.NOOP_CMD.match(bare):
            kind, why = "invalid", f"no-op command {bare!r}"
        elif not cs.RUNNABLE_HEAD.match(cs.LEADING_ENV.sub("", bare)):
            kind, why = "invalid", f"referential, not executable: {bare[:60]!r}"
        else:
            kind, why = "machine", ""
        out.append({"id": tid, "cmd": raw, "then": then, "kind": kind, "why": why})
    return out


def user_visible_gap(host: Path, sdd: Path, spec_id: str,
                     oracles: list[dict[str, str]]) -> str:
    """Non-empty when this unit owes a user-visible requirement only unit tests."""
    if not oracles:
        return ""
    try:
        cs = _load_check_spec()
    except Exception:
        return ""
    contract = read_text_maybe(sdd / "specs" / spec_id / "contract.md")
    if not contract:
        return ""
    _, rows = cs.parse_md_table_after(contract, "Requirements")
    ids = {o["id"] for o in oracles}
    pooled = "\n".join(f"{o['cmd']} {o['then']}" for o in oracles)
    for row in rows:
        if cs.clean(row.get("优先级", "")).upper() != "P0":
            continue
        mapped = set(re.findall(r"T-\d+", cs.clean(row.get("Tests", ""))))
        if not (mapped & ids):
            continue
        text = " ".join(cs.clean(v) for v in row.values())
        # A declared human oracle satisfies the bar. classify_oracles already labelled
        # them, so this does not re-implement the vocabulary: `manual-only` reaches
        # NON_UNIT_ORACLE as prose that does not match, and refusing the template's own
        # escape hatch would be this gate's bug.
        human_here = any(o.get("kind") == "human" and o["id"] in mapped for o in oracles)
        if cs.USER_VISIBLE.search(text) and not human_here \
                and not cs.NON_UNIT_ORACLE.search(pooled):
            return (f"{cs.clean(row.get('ID',''))} is user-visible but this unit's oracles "
                    "are unit-only — needs a browser / i18n / mobile / human oracle")
    return ""


def read_text_maybe(p: Path) -> str:
    return p.read_text(encoding="utf-8") if p.is_file() else ""


def build_pack(
    host: Path,
    spec_id: str,
    slice_id: str,
    row: dict[str, str],
    *,
    extra_rows: list[dict[str, str]] | None = None,
    dispatch_id: str = "",
) -> dict:
    sdd = resolve_sdd_root(host)
    rows = [row] + (extra_rows or [])
    t_ids: list[str] = []
    paths: list[str] = []
    deps: list[str] = []
    entries: list[str] = []
    slice_ids: list[str] = []
    for r in rows:
        sid = r.get("slice_id") or slice_id
        if sid not in slice_ids:
            slice_ids.append(sid)
        entries.append(f"{sid}:{r.get('entry') or '(见 plan.md 本片入口)'}")
        for t in extract_t_ids(r.get("done_def", "")):
            if t not in t_ids:
                t_ids.append(t)
        for p in extract_paths(r.get("paths_raw", ""), r.get("note", "")):
            if p not in paths:
                paths.append(p)
        d = (r.get("deps") or "").strip()
        if d and d not in deps:
            deps.append(d)
    pointers = rel_spec_files(sdd, host, spec_id)
    if len(slice_ids) == 1:
        goal = f"完成切片 {slice_ids[0]}：{rows[0].get('entry') or '(见 plan.md 本片入口)'}"
    else:
        goal = f"完成派发单元 {dispatch_id or slice_ids[0]}（切片 {', '.join(slice_ids)}）"
    if t_ids:
        goal += f"（Oracle：{', '.join(t_ids)}）"

    return {
        "slice_id": slice_ids[0],
        "slice_ids": slice_ids,
        "dispatch_id": dispatch_id or slice_ids[0],
        "spec_id": spec_id,
        "goal": goal,
        "entry": " | ".join(entries),
        "t_ids": t_ids,
        "oracles": classify_oracles(sdd, spec_id, t_ids),
        "visible_gap": user_visible_gap(host, sdd, spec_id,
                                       classify_oracles(sdd, spec_id, t_ids)),
        "paths": paths,
        "pointers": pointers,
        "deps": "; ".join(deps),
        "done_def": "; ".join(r.get("done_def", "") for r in rows if r.get("done_def")),
    }


def render_prompt(pack: dict, docs_hint: str) -> str:
    slice_ids = pack.get("slice_ids") or [pack["slice_id"]]
    slice_csv = ",".join(slice_ids)
    dispatch_id = pack.get("dispatch_id") or slice_ids[0]
    t_ids = ", ".join(pack["t_ids"]) if pack["t_ids"] else "(见 plan.md 本片完成定义)"
    if pack["paths"]:
        paths = "\n".join(f"  - {p}" for p in pack["paths"])
        allow_note = "ALLOWLIST is hard: do not read/write outside these paths (+ Spec pointers)."
    else:
        paths = "  - (MISSING allowlist — conductor must not dispatch)"
        allow_note = "ALLOWLIST missing: refuse to wander the repo; fail if conductor still sent this."
    pointers = "\n".join(f"  - {p}" for p in pack["pointers"]) if pack["pointers"] else f"  - {docs_hint}/specs/{pack['spec_id']}/"
    machine = [o for o in pack.get("oracles", []) if o.get("kind") == "machine"]
    human = [o for o in pack.get("oracles", []) if o.get("kind") == "human"]
    if machine:
        oracle_block = "\n".join(
            f"  {o['id']}  cmd:  {o['cmd']}\n        then: {o['then'] or '(no Then body)'}"
            for o in machine
        )
    else:
        oracle_block = "  (none — this unit has no machine-checked Oracle)"
    if human:
        human_block = "\n\n## 人工判定（**不进 replay 集**；关版走验收包，runner 不断言这些）\n" + "\n".join(
            f"  {o['id']}  then: {o['then'] or '(no Then body)'}" for o in human
        )
    else:
        human_block = ""
    replay_ids = ", ".join(o["id"] for o in machine) or "(none)"
    only = "只做本派发单元内的切片；禁止顺手做单元外切片或重构无关模块。"
    if len(slice_ids) > 1:
        only = f"本 exec 一次做完切片 {slice_csv}（同一派发单元）。禁止再开新会话/压缩后续做剩下的片。"

    return f"""DISPATCH_ID={dispatch_id}
SLICE_IDS={slice_csv}
SLICE_ID={slice_ids[0]}
SPEC_ID={pack['spec_id']}

## Goal
{pack['goal']}
{only}

## Context
Spec pointers (read from disk; do not expect full text in this prompt):
{pointers}
Allowlist / write-set for this dispatch unit:
{paths}
Deps: {pack['deps'] or 'n/a'}

## Oracle（冻结 · runner 逐条 replay，不由你自选，也不要改 tests.md）
{oracle_block}{human_block}

## Constraints
- Follow host AGENTS.md and vibe-coding quality bars **except** mid-flow human approval: this Pack is already authorized via CLI (`approval_policy=never`). Do NOT wait for 批准 / ask clarifying questions / use doc-coauthoring.
- {allow_note}
- Diff must stay within the allowlist; respect Out of Scope in contract.md.
- Do NOT modify tests.md or product acceptance-matrix Oracle (钉 2).
- UI changes: read plugin design-standards LOAD-MAP first; note refinement|redesign if touching existing UI.
- Prefer reading files via tools over assuming prompt pasted the codebase.
- Stay inside one Codex window: do not explore the whole monorepo. If context pressure rises, finish the allowlist diff and stop — do not auto-compact onward.
- Final message: short status + evidence only — zero questions.

## Done when
- {replay_ids} pass when the **runner** replays them, and the runner has already
  confirmed each one FAILS on the pre-change tree. Green-only is not evidence.
- `run.md` records the T-xxx results with `oracle-freeze: intact`.
- Short report only: what shipped, evidence paths, next dispatch unit — no "可交付".

按 vibe-coding Build 本派发单元；对照 contract 事实映射再改。
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

    wants = [w.strip() for w in re.split(r"[,+\s]+", args.slice_id.strip()) if w.strip()]
    if not wants:
        die("slice_id required (or pass --list)", 2)
    selected: list[dict[str, str]] = []
    for want in wants:
        row = next((r for r in rows if r["slice_id"].lower() == want.lower()), None)
        if row is None:
            known = ", ".join(r["slice_id"] for r in rows)
            die(f"slice '{want}' not in plan.md (have: {known})")
        selected.append(row)

    dispatch_id = ""
    if len(selected) > 1:
        dispatch_id = f"D-{'-'.join(r['slice_id'] for r in selected)}"
    pack = build_pack(
        host,
        args.spec_id,
        selected[0]["slice_id"],
        selected[0],
        extra_rows=selected[1:],
        dispatch_id=dispatch_id,
    )
    if not pack["t_ids"]:
        print(
            "build_context_pack: WARN no T-xxx in 完成定义 — pack still emitted",
            file=sys.stderr,
        )

    bad = [o for o in pack.get("oracles", []) if o.get("kind") == "invalid"]
    if bad:
        for o in bad:
            die_msg = f"{o['id']}: {o['why']}"
            print(f"build_context_pack: REFUSED — {die_msg}", file=sys.stderr)
        print("build_context_pack: a dispatch payload may not claim the runner will replay "
              "an Oracle it cannot execute. Fix tests.md 自动化 命令 (or mark it `human`).",
              file=sys.stderr)
        sys.exit(2)
    if pack.get("visible_gap"):
        print(f"build_context_pack: REFUSED — {pack['visible_gap']}", file=sys.stderr)
        sys.exit(2)

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
