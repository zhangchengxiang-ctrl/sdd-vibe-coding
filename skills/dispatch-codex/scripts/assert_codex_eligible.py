#!/usr/bin/env python3
"""Codex slice eligibility gate. Exit 0 eligible, 2 ineligible. See codex-boundary.md."""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path

MAX_ALLOWLIST_PATHS = 8

EXTENSIONLESS_FILES = frozenset({
    "Makefile", "GNUmakefile", "Dockerfile", "Containerfile", "Jenkinsfile",
    "Procfile", "Gemfile", "Rakefile", "Vagrantfile", "justfile", "LICENSE",
    "CODEOWNERS",
})

UI_PATH_RE = re.compile(
    r"\.(tsx|jsx|vue|svelte|css|scss|sass|less|html)$", re.I
)
NOTE_HUMAN_LAB = re.compile(r"(?i)oracle\s*:\s*(human|lab)\b")
NOTE_CONDUCTOR = re.compile(r"(?i)executor\s*:\s*conductor\b")
NOTE_UI = re.compile(
    r"(?i)(page_kind|motif|product-judgment|LOAD-MAP|\bvisual\b)"
)
NOTE_ARCH = re.compile(r"(?i)(\bADR\b|架构差量|新边界)")


def _load_pack():
    path = Path(__file__).resolve().parent / "build_context_pack.py"
    spec = importlib.util.spec_from_file_location("sdd_pack", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def is_directory_allowlist(path: str) -> bool:
    p = path.strip().strip("`")
    if not p:
        return True
    if p.endswith("/"):
        return True
    base = p.rsplit("/", 1)[-1]
    if not base or base in {".", ".."}:
        return True
    # Well-known files with no extension: a Makefile is a file, not a directory.
    if base in EXTENSIONLESS_FILES:
        return False
    if base.startswith(".") and "." not in base[1:]:
        return False
    return "." not in base


def evaluate_slice(host: Path, spec_id: str, slice_id: str) -> tuple[bool, list[str]]:
    """Return (eligible, reason codes)."""
    pack = _load_pack()
    sdd = pack.resolve_sdd_root(host)
    plan_path = sdd / "specs" / spec_id / "plan.md"
    reasons: list[str] = []
    if not plan_path.is_file():
        return False, ["no-plan"]

    rows = pack.find_slice_table(plan_path.read_text(encoding="utf-8"))
    row = next((r for r in rows if r["slice_id"].lower() == slice_id.lower()), None)
    if row is None:
        return False, ["unknown-slice"]

    blob = f"{row.get('entry', '')} {row.get('note', '')} {row.get('paths_raw', '')}"
    if NOTE_CONDUCTOR.search(blob):
        reasons.append("executor-conductor")
    if NOTE_HUMAN_LAB.search(blob):
        reasons.append("oracle-human-or-lab")
    if NOTE_ARCH.search(blob):
        reasons.append("architecture")
    if NOTE_UI.search(blob):
        reasons.append("ui-judgment")

    paths = pack.extract_paths(row.get("paths_raw", ""), row.get("note", ""))
    if not paths:
        reasons.append("empty-allowlist")
    else:
        if len(paths) > MAX_ALLOWLIST_PATHS:
            reasons.append("allowlist-too-wide")
        if any(is_directory_allowlist(p) for p in paths):
            reasons.append("directory-allowlist")
        if any(UI_PATH_RE.search(p) for p in paths):
            reasons.append("ui-path")

    t_ids = pack.extract_t_ids(row.get("done_def", ""))
    if not t_ids:
        reasons.append("no-t-ids")
        oracles: list[dict] = []
    else:
        oracles = pack.classify_oracles(sdd, spec_id, t_ids)

    if oracles:
        kinds = {o.get("kind") for o in oracles}
        if "invalid" in kinds:
            reasons.append("oracle-invalid")
        if "human" in kinds:
            reasons.append("oracle-human")
        if "machine" not in kinds:
            reasons.append("no-machine-oracle")
    elif t_ids:
        reasons.append("no-machine-oracle")

    gap = pack.user_visible_gap(host, sdd, spec_id, oracles) if oracles else ""
    if gap:
        reasons.append("user-visible-gap")

    return (len(reasons) == 0), reasons


def eligible_slice_ids(host: Path, spec_id: str) -> list[str] | None:
    """Slice ids that may be dispatched. None if plan cannot be parsed."""
    pack = _load_pack()
    sdd = pack.resolve_sdd_root(host)
    plan_path = sdd / "specs" / spec_id / "plan.md"
    if not plan_path.is_file():
        return None
    rows = pack.find_slice_table(plan_path.read_text(encoding="utf-8"))
    if not rows:
        return None
    out: list[str] = []
    for r in rows:
        ok, _ = evaluate_slice(host, spec_id, r["slice_id"])
        if ok:
            out.append(r["slice_id"])
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("host")
    ap.add_argument("spec_id")
    ap.add_argument("slice_id", nargs="?")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()
    host = Path(args.host).resolve()
    if not host.is_dir():
        print("assert_codex_eligible: host is not a directory", file=sys.stderr)
        raise SystemExit(2)
    if args.all:
        ids = eligible_slice_ids(host, args.spec_id)
        if ids is None:
            print("ineligible no-plan", file=sys.stderr)
            raise SystemExit(2)
        print("eligible " + (" ".join(ids) if ids else "(none)"))
        raise SystemExit(0)
    if not args.slice_id:
        print("assert_codex_eligible: slice_id required (or --all)", file=sys.stderr)
        raise SystemExit(2)
    ok, reasons = evaluate_slice(host, args.spec_id, args.slice_id)
    tag = "eligible" if ok else "ineligible"
    extra = " ".join(reasons) if reasons else "ok"
    print(f"{tag} {extra}")
    raise SystemExit(0 if ok else 2)


if __name__ == "__main__":
    main()
