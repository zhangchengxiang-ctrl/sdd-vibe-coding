#!/usr/bin/env python3
"""Run read-only Codex evaluations of the Spec Run protocol."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

FIELDS = ("mode", "spec_run_state", "may_write_code")

def main() -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    cases = json.loads((root / "evals/routing-contract-cases.json").read_text(encoding="utf-8"))["cases"]
    selected = cases if args.all else [c for c in cases if c["id"] in args.case]
    if not selected:
        print("ERROR: select --case or --all", file=sys.stderr)
        return 2
    if args.dry_run:
        print("DRY RUN: " + ", ".join(c["id"] for c in selected))
        return 0
    schema = (root / "evals/routing-output.schema.json").read_text(encoding="utf-8")
    failures = []
    with tempfile.TemporaryDirectory(prefix="spec-run-eval-") as temp:
        host = Path(temp)
        (host / "AGENTS.md").write_text("Read-only evaluation. Do not modify files or deploy.\n", encoding="utf-8")
        for case in selected:
            prompt = ("Use $vibe-coding. Read-only protocol evaluation. Return only JSON matching this schema: " + schema + "\n"
                      + "Do not execute the request. Decide the current Spec Run state.\nUser request: " + case["prompt"])
            result = subprocess.run(["codex", "exec", "-C", str(host), "--sandbox", "read-only", prompt], text=True, capture_output=True)
            try:
                actual = json.loads(result.stdout)
            except json.JSONDecodeError:
                failures.append(f"{case['id']}: invalid JSON: {result.stdout[-200:]}")
                continue
            mismatch = [f for f in FIELDS if actual.get(f) != case["expected"].get(f)]
            if mismatch:
                failures.append(f"{case['id']}: mismatched {', '.join(mismatch)}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"OK: {len(selected)} live Spec Run evaluations")
    return 0

raise SystemExit(main())
