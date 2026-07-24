#!/usr/bin/env python3
"""Validate Spec Run routing fixtures without claiming model behavior."""
from __future__ import annotations
import json
import pathlib
import sys

MODES = {"shape", "plan", "build", "verify", "repair", "diagnose", "incident"}
RUN_STATES = {"not-started", "continuous-build", "batch-unit-test", "batch-verify", "unified-repair", "completed", "blocked", "needs-authorization"}

def main() -> int:
    if len(sys.argv) != 2:
        return 2
    cases = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")).get("cases", [])
    ids = set()
    errors = []
    for case in cases:
        case_id, expected = case.get("id"), case.get("expected", {})
        if not isinstance(case_id, str) or case_id in ids:
            errors.append(f"invalid or duplicate id: {case_id!r}")
        ids.add(case_id)
        if expected.get("mode") not in MODES:
            errors.append(f"{case_id}: invalid mode")
        if expected.get("spec_run_state") not in RUN_STATES:
            errors.append(f"{case_id}: invalid spec_run_state")
        if expected.get("may_write_code") and expected.get("mode") in {"shape", "plan", "verify", "diagnose"}:
            errors.append(f"{case_id}: read-only mode may not write code")
    if errors:
        print("\n".join(f"ERROR: {e}" for e in errors), file=sys.stderr)
        return 1
    print(f"OK: {len(cases)} Spec Run fixtures")
    return 0

raise SystemExit(main())
