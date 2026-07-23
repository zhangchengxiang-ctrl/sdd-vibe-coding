#!/usr/bin/env python3
"""Run fresh, read-only Codex routing evaluations against the local Skills."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any


COMPARE_FIELDS = (
    "rail",
    "may_write_code",
    "may_deploy",
    "requires_work_order",
    "workspace",
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


def prepare_host(root: Path, temp_root: Path) -> Path:
    host = temp_root / "host"
    skill_root = host / ".agents/skills"
    skill_root.mkdir(parents=True)
    for name in SKILLS:
        destination = skill_root / f"sdd-eval-{name}"
        shutil.copytree(root / "skills" / name, destination)
        skill_md = destination / "SKILL.md"
        text = skill_md.read_text(encoding="utf-8")
        text = text.replace(
            f"name: {name}",
            f"name: sdd-eval-{name}",
            1,
        )
        skill_md.write_text(text, encoding="utf-8")
    (host / "AGENTS.md").write_text(
        "# Routing evaluation fixture\n\n"
        "This repository is read-only. The request is hypothetical. "
        "Do not modify files, run implementation commands, or deploy anything.\n",
        encoding="utf-8",
    )
    return host


def evaluation_prompt(case: dict[str, Any]) -> str:
    return (
        "Use $sdd-eval-vibe-coding. This is a routing-only evaluation in a read-only "
        "fixture. "
        "Do not execute the requested work, modify files, run implementation commands, "
        "ask follow-up questions, or deploy. Decide what is authorized at this exact "
        "moment, not what a later rail may authorize. The read-only evaluation harness "
        "must not influence the workspace field: report the workspace policy for the "
        "hypothetical request, use n/a when no execution workspace should be selected "
        "yet, and use blocked only when the user request lacks facts required for the "
        "selected rail. Return only the JSON object required by the output schema.\n\n"
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
        host = prepare_host(root, temp_root)
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
            command.append(evaluation_prompt(case))
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
