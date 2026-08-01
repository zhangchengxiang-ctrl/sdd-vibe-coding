#!/usr/bin/env python3
"""Probe cursor-agent: required skill/reference files appear in Read tool_calls.

Maintainer live check (needs `cursor-agent` login). Not a host product gate.

Usage:
  python3 scripts/eval-skill-load-cursor.py --matrix          # all load-tier matrix cases
  python3 scripts/eval-skill-load-cursor.py --all             # legacy skill-load/cases.json
  python3 scripts/eval-skill-load-cursor.py --case UI-LOAD-LIST
  make eval-skill-load
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEGACY_CASES = ROOT / "scripts" / "fixtures" / "skill-load" / "cases.json"
MATRIX = ROOT / "scripts" / "fixtures" / "capability-matrix" / "cases.json"
DEFAULT_AGENT = "cursor-agent"

# Prefer these absolute files when a substring matches.
PLUGIN_PATH_HINTS: list[tuple[str, str]] = [
    ("vibe-coding/SKILL.md", "skills/vibe-coding/SKILL.md"),
    ("testing/SKILL.md", "skills/testing/SKILL.md"),
    ("design/SKILL.md", "skills/design/SKILL.md"),
    ("project-init.md", "skills/design/references/project-init.md"),
    ("codebase-grounding.md", "skills/design/references/codebase-grounding.md"),
    ("ux-standards.md", "skills/testing/references/ux-standards.md"),
    ("falsify-checklist.md", "skills/testing/references/falsify-checklist.md"),
    ("product-judgment.md", "skills/vibe-coding/references/design-standards/product-judgment.md"),
    ("LOAD-MAP.md", "skills/vibe-coding/references/design-standards/LOAD-MAP.md"),
    ("change-control.md", "skills/vibe-coding/references/design-standards/change-control.md"),
    ("craft-knobs.md", "skills/vibe-coding/references/design-standards/craft-knobs.md"),
    ("surfaces/README.md", "skills/vibe-coding/references/design-standards/surfaces/README.md"),
    ("surfaces/product.md", "skills/vibe-coding/references/design-standards/surfaces/product.md"),
    ("surfaces/consumer.md", "skills/vibe-coding/references/design-standards/surfaces/consumer.md"),
    ("product-shells.md", "skills/vibe-coding/references/design-standards/surfaces/product-shells.md"),
    ("pages/list.md", "skills/vibe-coding/references/design-standards/pages/list.md"),
    ("pages/detail.md", "skills/vibe-coding/references/design-standards/pages/detail.md"),
    ("pages/settings.md", "skills/vibe-coding/references/design-standards/pages/settings.md"),
    ("pages/dashboard.md", "skills/vibe-coding/references/design-standards/pages/dashboard.md"),
    ("pages/form.md", "skills/vibe-coding/references/design-standards/pages/form.md"),
    ("pages/consumer.md", "skills/vibe-coding/references/design-standards/pages/consumer.md"),
    ("product-datatable.md", "skills/vibe-coding/references/design-standards/components/product-datatable.md"),
    ("overlays.md", "skills/vibe-coding/references/design-standards/components/overlays.md"),
    ("bulk-actions.md", "skills/vibe-coding/references/design-standards/components/bulk-actions.md"),
    ("command-palette.md", "skills/vibe-coding/references/design-standards/components/command-palette.md"),
    ("product-forms-states.md", "skills/vibe-coding/references/design-standards/components/product-forms-states.md"),
    ("copy.md", "skills/vibe-coding/references/design-standards/copy.md"),
    ("color-roles.md", "skills/vibe-coding/references/design-standards/tokens/color-roles.md"),
    ("web-interface.md", "skills/vibe-coding/references/design-standards/audit/web-interface.md"),
    ("ai-tells.md", "skills/vibe-coding/references/design-standards/audit/ai-tells.md"),
    ("debug-playbook.md", "skills/vibe-coding/references/design-standards/debug-playbook.md"),
]


def resolve_required_paths(plugin_dir: Path, host: Path, substrings: list[str]) -> list[str]:
    out: list[str] = []
    for sub in substrings:
        if sub == "AGENTS.md" or sub.endswith("/AGENTS.md"):
            out.append(str(host / "AGENTS.md"))
            continue
        hit = None
        for key, rel in PLUGIN_PATH_HINTS:
            if sub == key or sub.endswith(key) or key.endswith(sub):
                hit = plugin_dir / rel
                break
        if hit is None:
            # fallback: search under plugin
            matches = list(plugin_dir.rglob(Path(sub).name))
            # prefer path containing the substring
            ranked = [p for p in matches if sub in str(p)] or matches
            if ranked:
                hit = ranked[0]
        if hit is None:
            raise FileNotFoundError(f"cannot resolve required read: {sub}")
        if not hit.is_file():
            raise FileNotFoundError(f"missing required file for {sub}: {hit}")
        out.append(str(hit))
    return out


def build_probe_prompt(case: dict, plugin_dir: Path, host: Path) -> str:
    if case.get("probe_prompt"):
        body = case["probe_prompt"]
    elif "HARD RULES" in (case.get("prompt") or ""):
        body = case["prompt"]
    else:
        reqs = resolve_required_paths(
            plugin_dir, host, list(case.get("must_read_substrings") or [])
        )
        req_lines = "\n".join(f"   - {p}" for p in reqs)
        intent = case.get("prompt") or case["id"]
        body = (
            f"Skill-load probe id={case['id']}.\n"
            f"User intent (context only): {intent}\n\n"
            "HARD RULES:\n"
            "1) Do NOT open a browser, do NOT edit/write files, do NOT run long shells.\n"
            "2) Your FIRST tool uses MUST be Read on exactly these files (in order):\n"
            f"{req_lines}\n"
            "3) After those Reads, stop. Reply with ONLY JSON (no markdown fence):\n"
            f'{{"probe":"{case["id"]}","ok":true}}\n'
        )
    return (
        f"Plugin directory: {plugin_dir}\n"
        f"Workspace (throwaway host): {host}\n\n"
        + body
    )


def extract_read_paths(stream_lines: list[str]) -> list[str]:
    paths: list[str] = []
    for line in stream_lines:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") != "tool_call":
            continue
        tc = obj.get("tool_call") or {}
        read = tc.get("readToolCall") or {}
        args = read.get("args") or {}
        path = args.get("path")
        if isinstance(path, str) and path:
            if not paths or paths[-1] != path:
                paths.append(path)
    return paths


def extract_result_text(stream_lines: list[str]) -> str:
    for line in reversed(stream_lines):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "result" and isinstance(obj.get("result"), str):
            return obj["result"]
        if obj.get("type") == "assistant":
            msg = obj.get("message") or {}
            content = msg.get("content") or []
            texts = [
                p.get("text", "")
                for p in content
                if isinstance(p, dict) and p.get("type") == "text"
            ]
            if texts:
                return "\n".join(texts)
    return ""


def grade(case: dict, read_paths: list[str], result_text: str) -> list[str]:
    fails: list[str] = []
    required = case.get("must_read_substrings") or []
    max_idx = int(case.get("max_read_index_for_required") or max(12, len(required) + 4))
    window = read_paths[: max(0, max_idx)]
    blob = "\n".join(window)
    for sub in required:
        if sub not in blob:
            anywhere = any(sub in p for p in read_paths)
            if anywhere:
                fails.append(f"read-order: {sub} found but not within first {max_idx} reads")
            else:
                fails.append(f"missing-read: {sub}")
    for needle in case.get("result_must_contain") or []:
        if needle not in result_text:
            fails.append(f"missing-result: {needle}")
    return fails


def load_cases(source: str) -> list[dict]:
    if source == "legacy":
        return json.loads(LEGACY_CASES.read_text(encoding="utf-8"))["cases"]
    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    out: list[dict] = []
    for case in matrix["cases"]:
        tiers = case.get("tier") or []
        if "load" not in tiers:
            continue
        if not case.get("must_read_substrings"):
            continue
        # bump tight windows for entry cases
        c = dict(case)
        if c["id"] == "K-SOFT-ENTRY":
            c["max_read_index_for_required"] = 6
        elif not c.get("max_read_index_for_required"):
            c["max_read_index_for_required"] = max(10, len(c["must_read_substrings"]) + 4)
        c.setdefault("timeout_sec", 180)
        out.append(c)
    return out


def run_case(
    case: dict,
    *,
    agent: str,
    plugin_dir: Path,
    model: str | None,
) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="skill-load-") as tmp:
        host = Path(tmp)
        (host / "AGENTS.md").write_text(
            "project.kind: software\n"
            "SDD docs root: docs\n"
            "Read-only skill-load probe host. Do not deploy.\n",
            encoding="utf-8",
        )
        (host / "docs" / "product").mkdir(parents=True)
        (host / "docs" / "product" / "README.md").write_text(
            "# Probe product\nSkill-load only.\n",
            encoding="utf-8",
        )

        # Fail fast if required files missing in plugin
        try:
            resolve_required_paths(
                plugin_dir, host, list(case.get("must_read_substrings") or [])
            )
        except FileNotFoundError as exc:
            return False, f"{case['id']}: resolve-error: {exc}"

        prompt = build_probe_prompt(case, plugin_dir, host)
        cmd = [
            agent,
            "--print",
            "--output-format",
            "stream-json",
            "--trust",
            "--force",
            "--sandbox",
            "enabled",
            "--workspace",
            str(host),
            "--plugin-dir",
            str(plugin_dir),
            prompt,
        ]
        if model:
            cmd[1:1] = ["--model", model]

        timeout = int(case.get("timeout_sec") or 180)
        try:
            proc = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired:
            return False, f"{case['id']}: timeout after {timeout}s"

        lines = [ln for ln in (proc.stdout or "").splitlines() if ln.strip()]
        reads = extract_read_paths(lines)
        result = extract_result_text(lines)
        fails = grade(case, reads, result)
        detail = (
            f"reads({len(reads)})="
            + json.dumps(reads[:14], ensure_ascii=False)
            + f" result_head={result[:160]!r}"
        )
        if proc.returncode != 0 and not lines:
            return False, (
                f"{case['id']}: agent exit={proc.returncode} "
                f"stderr={proc.stderr[:200]!r}"
            )
        if fails:
            return False, f"{case['id']}: {'; '.join(fails)} | {detail}"
        return True, f"{case['id']}: OK | {detail}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--all", action="store_true", help="legacy skill-load/cases.json")
    parser.add_argument(
        "--matrix",
        action="store_true",
        help="capability-matrix load-tier cases (default for make eval-skill-load)",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--agent", default=DEFAULT_AGENT)
    parser.add_argument("--plugin-dir", type=Path, default=ROOT)
    parser.add_argument("--model", default=None)
    parser.add_argument(
        "--fail-fast",
        action="store_true",
        help="stop on first failure",
    )
    args = parser.parse_args()

    if shutil.which(args.agent) is None:
        print(f"ERROR: `{args.agent}` not on PATH", file=sys.stderr)
        return 2

    if args.matrix or (not args.all and not args.case):
        source = "matrix"
        cases = load_cases("matrix")
    else:
        source = "legacy"
        cases = load_cases("legacy")

    selected = cases if (args.all or args.matrix or not args.case) else [
        c for c in cases if c["id"] in args.case
    ]
    # allow --case with matrix ids when --matrix not set
    if args.case and not selected:
        cases = load_cases("matrix") + load_cases("legacy")
        selected = [c for c in cases if c["id"] in args.case]
        # dedupe by id
        seen: set[str] = set()
        uniq = []
        for c in selected:
            if c["id"] in seen:
                continue
            seen.add(c["id"])
            uniq.append(c)
        selected = uniq

    if args.all and source == "legacy":
        selected = load_cases("legacy")
    if args.matrix:
        selected = load_cases("matrix")
    if args.case:
        pool = load_cases("matrix") + load_cases("legacy")
        selected = []
        seen = set()
        for cid in args.case:
            for c in pool:
                if c["id"] == cid and cid not in seen:
                    selected.append(c)
                    seen.add(cid)

    if not selected:
        print("ERROR: no cases selected", file=sys.stderr)
        return 2

    if args.dry_run:
        print(f"DRY RUN ({len(selected)}):", ", ".join(c["id"] for c in selected))
        return 0

    ok_n = 0
    failures: list[str] = []
    print(f"Running {len(selected)} cases (plugin={args.plugin_dir})")
    for case in selected:
        print(f"== {case['id']} ==")
        passed, msg = run_case(
            case,
            agent=args.agent,
            plugin_dir=args.plugin_dir.resolve(),
            model=args.model,
        )
        print(msg, flush=True)
        if passed:
            ok_n += 1
        else:
            failures.append(msg)
            if args.fail_fast:
                break

    print("--------")
    print(f"PASS={ok_n} FAIL={len(failures)} TOTAL={len(selected)}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
