#!/usr/bin/env python3
"""Post-Plan disk gate: Spec 五件套 must exist and be non-empty.

Wish-path: chat-only「待批准执行计划」with exit 0 is a plugin failure.
Exit 0 = artifacts OK; exit 1 = missing/empty; exit 2 = usage.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED = ("VERSION.md", "contract.md", "tests.md", "plan.md", "run.md")

# Mid-flow approval stop phrases that must not dominate Plan output as the
# only deliverable. We fail if Spec files are missing; additionally fail if
# a marker file from a chat-only stop is present (optional). Scanning the
# five files for "请批准后再" style blockers that replace content is soft.
STOP_PHRASE_RE = re.compile(
    r"(待批准(?:的)?执行计划|执行计划（待批准）|请批准后再(?:落盘|写入|继续)|"
    r"等待(?:你的)?批准后(?:再)?(?:开始|落盘|写入)|"
    r"do\s+not\s+write\s+until\s+approved|"
    r"awaiting\s+(?:your\s+)?approval\s+before\s+(?:writing|landing))",
    re.IGNORECASE,
)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("host", type=Path)
    ap.add_argument("spec_id")
    ap.add_argument(
        "--allow-stop-phrases",
        action="store_true",
        help="Do not scan Spec files for mid-approval stop phrases",
    )
    args = ap.parse_args()
    host = args.host.resolve()
    if not host.is_dir():
        print(f"assert_plan_artifacts: host not a directory: {host}", file=sys.stderr)
        return 2

    docs_root = host / "docs"
    agents = host / "AGENTS.md"
    if agents.is_file():
        text = agents.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"(?im)^\s*SDD\s+docs\s+root\s*[:：]\s*`?([^`\n]+)`?", text)
        if m:
            rel = m.group(1).strip().strip("`").strip("/")
            cand = (host / rel).resolve()
            if cand.is_dir():
                docs_root = cand

    import importlib.util
    sp_path = Path(__file__).resolve().parents[2] / "spec" / "scripts" / "spec_paths.py"
    sp_spec = importlib.util.spec_from_file_location("spec_paths_apa", sp_path)
    sp = importlib.util.module_from_spec(sp_spec)
    sp_spec.loader.exec_module(sp)
    try:
        found = sp.find_spec_dir(docs_root, args.spec_id, sp.archive_names(host) | {"archive"})
    except sp.AmbiguousSpec as e:
        print(f"assert_plan_artifacts: {e}", file=sys.stderr)
        return 1
    # A Spec that does not exist yet is expected under an iteration; the error names that place.
    spec_dir = found if found is not None else docs_root / "iterations" / "<yyyy-mm>" / "<w>" / "<版本>" / args.spec_id
    errors: list[str] = []
    for name in REQUIRED:
        path = spec_dir / name
        rel: str | Path
        try:
            rel = path.relative_to(host)
        except ValueError:
            rel = path
        if not path.is_file():
            errors.append(f"missing {rel}")
            continue
        if path.stat().st_size < 32:
            errors.append(f"empty/too-small {rel}")
            continue
        if not args.allow_stop_phrases:
            body = path.read_text(encoding="utf-8", errors="replace")
            if STOP_PHRASE_RE.search(body) and len(body) < 400:
                errors.append(
                    f"stop-phrase-dominated {path.name}: mid-flow 待批准 is forbidden on wish Plan"
                )

    if errors:
        print("assert_plan_artifacts: FAIL — Plan must land Spec files on disk", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        print(
            "  Wish-path: no 待批准停点; write VERSION/contract/tests/plan/run under docs/iterations/<yyyy-mm>/<w>/<版本>/<spec-id>/",
            file=sys.stderr,
        )
        return 1

    print(f"assert_plan_artifacts: ok ({spec_dir})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
