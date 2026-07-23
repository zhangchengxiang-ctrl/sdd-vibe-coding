#!/usr/bin/env python3
"""Validate human-authored routing contract fixtures without claiming model behavior."""

from __future__ import annotations

import json
import pathlib
import sys


RAILS = {"shape", "plan", "build", "verify", "repair", "diagnose", "incident"}
WORKSPACES = {"n/a", "local", "codex-worktree", "git-worktree", "blocked"}
WORK_ORDER_STATES = {"not-needed", "to-create", "ready", "missing"}
SOURCE_SCOPES = {
    "product-and-current-system",
    "approved-product-and-code",
    "task-route-and-code",
    "scenarios-and-runtime",
    "production-evidence",
}
WRITE_SCOPES = {
    "product-docs",
    "spec-and-work-orders",
    "task-boundary",
    "validation-evidence",
    "diagnosis-record",
    "incident-record",
}
ARTIFACTS = {
    "product-slice",
    "technical-plan-and-work-orders",
    "task-evidence",
    "validation-report",
    "diagnosis",
    "incident-work-order",
    "production-verification",
}
STOP_CONDITIONS = {
    "design-ready",
    "code-ready",
    "task-passed",
    "matrix-accounted",
    "root-cause-located",
    "incident-plan-ready",
    "production-restored",
}
NO_CODE_RAILS = {"shape", "plan", "verify", "diagnose"}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)


def main() -> int:
    if len(sys.argv) != 2:
        fail("usage: verify-contract-fixtures.py <routing-contract-cases.json>")
        return 2

    path = pathlib.Path(sys.argv[1])
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(str(exc))
        return 1

    cases = payload.get("cases")
    if not isinstance(cases, list) or not cases:
        fail("cases must be a non-empty list")
        return 1

    errors = 0
    ids: set[str] = set()
    covered_rails: set[str] = set()
    worktree_count = 0
    local_count = 0

    for index, case in enumerate(cases, start=1):
        label = f"case #{index}"
        if not isinstance(case, dict):
            fail(f"{label} must be an object")
            errors += 1
            continue

        case_id = case.get("id")
        prompt = case.get("prompt")
        expected = case.get("expected")
        if not isinstance(case_id, str) or not case_id:
            fail(f"{label} missing id")
            errors += 1
            continue
        if case_id in ids:
            fail(f"duplicate id: {case_id}")
            errors += 1
        ids.add(case_id)
        label = case_id
        if not isinstance(prompt, str) or not prompt.strip():
            fail(f"{label}: prompt must be non-empty")
            errors += 1
        if not isinstance(expected, dict):
            fail(f"{label}: expected must be an object")
            errors += 1
            continue

        rail = expected.get("rail")
        workspace = expected.get("workspace")
        may_write_code = expected.get("may_write_code")
        may_deploy = expected.get("may_deploy")
        work_order_state = expected.get("work_order_state")
        source_scope = expected.get("source_scope")
        write_scope = expected.get("write_scope")
        artifact = expected.get("expected_artifact")
        stop_condition = expected.get("stop_condition")

        if rail not in RAILS:
            fail(f"{label}: invalid rail {rail!r}")
            errors += 1
        else:
            covered_rails.add(rail)
        if workspace not in WORKSPACES:
            fail(f"{label}: invalid workspace {workspace!r}")
            errors += 1
        if not all(isinstance(value, bool) for value in (may_write_code, may_deploy)):
            fail(f"{label}: boolean authorization fields are required")
            errors += 1
            continue
        if work_order_state not in WORK_ORDER_STATES:
            fail(f"{label}: invalid work_order_state {work_order_state!r}")
            errors += 1
        for value, allowed, field in [
            (source_scope, SOURCE_SCOPES, "source_scope"),
            (write_scope, WRITE_SCOPES, "write_scope"),
            (artifact, ARTIFACTS, "expected_artifact"),
            (stop_condition, STOP_CONDITIONS, "stop_condition"),
        ]:
            if value not in allowed:
                fail(f"{label}: invalid {field} {value!r}")
                errors += 1

        if rail in NO_CODE_RAILS and may_write_code:
            fail(f"{label}: {rail} cannot write business code")
            errors += 1
        if may_deploy and rail != "incident":
            fail(f"{label}: only an explicitly authorized incident case may deploy")
            errors += 1
        if rail in {"build", "repair"} and work_order_state not in {"ready", "missing"}:
            fail(f"{label}: {rail} must have a ready or missing Work Order")
            errors += 1
        if rail == "incident" and (may_write_code or may_deploy) and work_order_state != "ready":
            fail(f"{label}: mutating Incident requires a ready Work Order")
            errors += 1
        if rail in {"shape", "verify", "diagnose"} and work_order_state != "not-needed":
            fail(f"{label}: {rail} must not create or consume an execution Work Order")
            errors += 1
        if work_order_state == "missing" and (
            may_write_code or may_deploy or workspace != "blocked"
        ):
            fail(f"{label}: missing Work Order must block mutation and workspace")
            errors += 1
        if work_order_state == "to-create" and (may_write_code or may_deploy):
            fail(f"{label}: Work Order creation rail cannot mutate implementation")
            errors += 1
        if workspace in {"codex-worktree", "git-worktree"}:
            worktree_count += 1
        if workspace == "local":
            local_count += 1

    missing = RAILS - covered_rails
    if missing:
        fail(f"missing rail coverage: {', '.join(sorted(missing))}")
        errors += 1
    if worktree_count < 2:
        fail("fixtures must cover at least two Worktree decisions")
        errors += 1
    if local_count < 2:
        fail("fixtures must cover at least two Local decisions")
        errors += 1

    if errors:
        return 1
    print(
        f"OK: {len(cases)} contract fixtures; rails={len(covered_rails)}; "
        f"local={local_count}; worktree={worktree_count}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
