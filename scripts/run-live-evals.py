#!/usr/bin/env python3
"""Run fresh, read-only Codex routing evaluations against the local Skills."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any


COMPARE_FIELDS = (
    "rail",
    "may_write_code",
    "may_deploy",
    "work_order_state",
    "workspace",
    "source_scope",
    "write_scope",
    "expected_artifact",
    "stop_condition",
)
SKILLS = ("vibe-coding", "design", "spec", "testing", "debug")


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description=(
            "Run real codex exec evaluations. This is intentionally separate from "
            "the deterministic contract-fixture check."
        )
    )
    parser.add_argument(
        "cases",
        nargs="?",
        type=Path,
        default=root / "evals/routing-contract-cases.json",
    )
    parser.add_argument("--case", action="append", dest="case_ids", default=[])
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--model")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--results", type=Path)
    return parser.parse_args()


def load_cases(path: Path, selected: set[str], run_all: bool) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    cases = payload["cases"]
    known = {case["id"] for case in cases}
    unknown = selected - known
    if unknown:
        raise ValueError(f"unknown case ids: {', '.join(sorted(unknown))}")
    if run_all:
        return cases
    if not selected:
        raise ValueError("select --case <id> or pass --all; live evals may incur usage")
    return [case for case in cases if case["id"] in selected]


def create_work_order_fixture(host: Path, case: dict[str, Any]) -> str | None:
    expected = case["expected"]
    if expected["work_order_state"] != "ready":
        return None

    rail = expected["rail"]
    workspace = expected["workspace"]
    if rail in {"build", "repair"}:
        match = re.search(r"T-\d{3}", case["prompt"])
        if not match:
            raise ValueError(f"{case['id']}: ready {rail} case must name T-xxx")
        task_id = match.group(0)
        spec_id = f"v2099.01-{case['id']}"
        spec_root = host / "docs/specs" / spec_id
        task_path = spec_root / "tasks" / f"{task_id}.md"
        route_path = spec_root / "routes" / f"{task_id}.next-rail.md"
        task_path.parent.mkdir(parents=True, exist_ok=True)
        route_path.parent.mkdir(parents=True, exist_ok=True)
        task_path.write_text(
            f"""# {task_id}: routing evaluation result

## 用户或系统结果

Complete the bounded result described by the evaluation request.

## 前置条件

- The Work Order is ready.

## In

- Only the named evaluation result.

## Out

- Deployment and unrelated changes.

## 技术影响面

- Evaluation fixture only.

## 写入边界

- The hypothetical Task boundary.

## 不变量

- Do not expand scope.

## 实现步骤

1. Execute only this Task.

## 验收条件

- The named result has direct evidence.

## 最低证据

- Task-specific evidence.

## Workspace Strategy

```yaml
workspace:
  mode: {workspace}
  base_ref: main
  base_sha: fixture
  branch: codex/{spec_id}-{task_id.lower()}
  setup: n/a
  shared_resources: []
  claims: []
```

## 风险与回滚

- Fixture only.

## 终态

`ready`
""",
            encoding="utf-8",
        )
        route_path.write_text(
            f"""---
rail: {rail}
spec: {spec_id}
task: {task_id}
objective: "Complete the bounded evaluation result"
source: docs/specs/{spec_id}/tasks/{task_id}.md
workspace: {workspace}
claims: []
stop_when: "Task acceptance has direct evidence"
on_pass: verify
on_fail: blocked-or-replan
---
""",
            encoding="utf-8",
        )
        return route_path.relative_to(host).as_posix()

    if rail == "incident":
        incident_path = host / "docs/operations/incidents/INC-EVAL.md"
        incident_path.parent.mkdir(parents=True, exist_ok=True)
        incident_path.write_text(
            """# Incident: routing evaluation

## Incident Work Order

- 状态：ready and approved
- 恢复目标：restore the production core service
- In：minimal Hotfix, authorized deployment, production verification
- Out：unrelated refactoring
- 写入边界：the isolated Hotfix only
- Workspace：codex-worktree
- Production Oracle：health and the core journey recover
- 回滚点：the previously stable release
""",
            encoding="utf-8",
        )
        return incident_path.relative_to(host).as_posix()

    raise ValueError(f"{case['id']}: unsupported ready Work Order rail {rail}")


def prepare_host(
    root: Path, temp_root: Path, cases: list[dict[str, Any]]
) -> tuple[Path, dict[str, str]]:
    host = temp_root / "host"
    skill_root = host / ".agents/skills"
    skill_root.mkdir(parents=True)
    for name in SKILLS:
        destination = skill_root / name
        shutil.copytree(root / "skills" / name, destination)
    (host / "AGENTS.md").write_text(
        "# Routing evaluation fixture\n\n"
        "This repository is read-only. The request is hypothetical. "
        "Do not modify files, run implementation commands, or deploy anything.\n",
        encoding="utf-8",
    )
    fixture_sources: dict[str, str] = {}
    for case in cases:
        source = create_work_order_fixture(host, case)
        if source:
            fixture_sources[case["id"]] = source
    return host, fixture_sources


def evaluation_prompt(case: dict[str, Any], fixture_source: str | None) -> str:
    activation = (
        ""
        if case.get("activation") == "implicit"
        else "Use $vibe-coding. "
    )
    fixture = (
        f"\nAuthoritative Work Order source: {fixture_source}. Read it before deciding.\n"
        if fixture_source
        else "\nNo execution Work Order exists in this fixture.\n"
    )
    return (
        activation
        + "This is a routing-only evaluation in a read-only fixture. "
        "Do not execute the requested work, modify files, run implementation commands, "
        "ask follow-up questions, or deploy. Decide what is authorized at this exact "
        "moment, not what a later rail may authorize. The read-only evaluation harness "
        "must not influence the workspace field: report the workspace policy for the "
        "hypothetical request, use n/a when no execution workspace should be selected "
        "yet, and use blocked only when the user request lacks facts required for the "
        "selected rail. For work_order_state use exactly: not-needed when the current "
        "rail neither creates nor consumes an execution Work Order; to-create when the "
        "current rail must create one before later mutation; ready when the supplied "
        "applicable Work Order is ready; missing when execution was requested but its "
        "required Work Order is unavailable. source_scope, write_scope, "
        "expected_artifact, and stop_condition describe the selected rail at this exact "
        "moment and must use the schema enums. Return only the JSON object required by "
        "the output schema."
        + fixture
        + "\n"
        f"User request:\n{case['prompt']}"
    )


def compare(expected: dict[str, Any], actual: dict[str, Any]) -> list[str]:
    return [
        f"{field}: expected={expected.get(field)!r} actual={actual.get(field)!r}"
        for field in COMPARE_FIELDS
        if expected.get(field) != actual.get(field)
    ]


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parent.parent
    schema = root / "evals/routing-output.schema.json"
    try:
        cases = load_cases(args.cases.resolve(), set(args.case_ids), args.all)
    except (OSError, KeyError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if args.dry_run:
        print(f"DRY RUN: {len(cases)} live cases")
        for case in cases:
            print(f"- {case['id']}")
        return 0

    if subprocess.run(
        ["codex", "--version"],
        capture_output=True,
        text=True,
        check=False,
    ).returncode:
        print("ERROR: codex CLI is required", file=sys.stderr)
        return 2

    results: list[dict[str, Any]] = []
    failures = 0
    with tempfile.TemporaryDirectory(prefix="sdd-live-eval-") as temp:
        temp_root = Path(temp)
        host, fixture_sources = prepare_host(root, temp_root, cases)
        for index, case in enumerate(cases, start=1):
            output = temp_root / f"{index:03d}-{case['id']}.json"
            command = [
                "codex",
                "exec",
                "--ephemeral",
                "--ignore-user-config",
                "--sandbox",
                "read-only",
                "--skip-git-repo-check",
                "--output-schema",
                str(schema),
                "--output-last-message",
                str(output),
                "--cd",
                str(host),
            ]
            if args.model:
                command.extend(["--model", args.model])
            command.append(
                evaluation_prompt(case, fixture_sources.get(case["id"]))
            )
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=args.timeout,
                check=False,
            )
            record: dict[str, Any] = {
                "id": case["id"],
                "expected": case["expected"],
                "exit_code": completed.returncode,
            }
            if completed.returncode:
                record["passed"] = False
                record["error"] = completed.stderr[-4000:]
                failures += 1
                print(f"FAIL {case['id']}: codex exit={completed.returncode}")
            else:
                try:
                    actual = json.loads(output.read_text(encoding="utf-8"))
                    mismatches = compare(case["expected"], actual)
                    record["actual"] = actual
                    record["mismatches"] = mismatches
                    record["passed"] = not mismatches
                    if mismatches:
                        failures += 1
                        print(f"FAIL {case['id']}: {'; '.join(mismatches)}")
                    else:
                        print(f"PASS {case['id']}")
                except (OSError, json.JSONDecodeError) as exc:
                    failures += 1
                    record["passed"] = False
                    record["error"] = str(exc)
                    print(f"FAIL {case['id']}: invalid JSON result: {exc}")
            results.append(record)

    if args.results:
        args.results.parent.mkdir(parents=True, exist_ok=True)
        args.results.write_text(
            json.dumps({"results": results}, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(f"RESULT: {len(cases) - failures}/{len(cases)} live cases passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
