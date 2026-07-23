#!/usr/bin/env python3
"""Validate SDD structure, routes, traceability, handoff, and parallel claims."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import sys


VERSION_STATUSES = {
    "draft",
    "ready",
    "in-progress",
    "verifying",
    "blocked",
    "done",
    "archived",
    "cancelled",
}
ACTIVE_VERSION_STATUSES = {"ready", "in-progress", "verifying", "blocked"}
TASK_STATUSES = {"ready", "in-progress", "passed", "failed", "blocked", "cancelled"}
RAILS = {"shape", "plan", "build", "verify", "repair", "diagnose", "incident"}
WORKSPACES = {"local", "codex-worktree", "git-worktree", "blocked", "n/a"}
CLAIM_TYPES = {"resource"}
CLAIM_STATUSES = {"active", "released"}
ROUTE_VERSION = "1"
ROUTE_REQUIRED_FIELDS = {
    "route_version",
    "route_id",
    "rail",
    "spec",
    "task",
    "objective",
    "source",
    "workspace",
    "owner",
    "claims",
    "stop_when",
    "on_pass",
    "on_fail",
}
ROUTE_NATIVE_FIELDS = {"thread_id", "subagent_id", "goal_id"}


class Report:
    def __init__(self) -> None:
        self.errors = 0
        self.warnings = 0

    def ok(self, message: str) -> None:
        print(f"OK: {message}")

    def fail(self, message: str) -> None:
        print(f"ERROR: {message}", file=sys.stderr)
        self.errors += 1

    def warn(self, message: str) -> None:
        print(f"WARN: {message}", file=sys.stderr)
        self.warnings += 1


def clean_cell(value: str) -> str:
    return value.strip().replace("`", "").replace("**", "")


def heading_level(line: str) -> int | None:
    match = re.match(r"^(#+)\s+", line)
    return len(match.group(1)) if match else None


def find_heading(
    lines: list[str],
    heading: str | tuple[str, ...],
) -> tuple[int, str] | None:
    candidates = (heading,) if isinstance(heading, str) else heading
    for candidate in candidates:
        try:
            return lines.index(candidate), candidate
        except ValueError:
            continue
    return None


def heading_label(heading: str | tuple[str, ...]) -> str:
    return heading if isinstance(heading, str) else " or ".join(heading)


def markdown_link_target(value: str) -> str | None:
    match = re.search(r"\[[^\]]+\]\(([^)]+)\)", value)
    return match.group(1) if match else None


def parse_table(
    path: Path,
    heading: str | tuple[str, ...],
    report: Report,
) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    found = find_heading(lines, heading)
    if found is None:
        report.fail(f"{path}: missing section {heading_label(heading)}")
        return []
    heading_index, actual_heading = found
    start = heading_index + 1
    target_level = heading_level(actual_heading)

    while start < len(lines) and not lines[start].lstrip().startswith("|"):
        level = heading_level(lines[start])
        if level is not None and target_level is not None and level <= target_level:
            report.fail(f"{path}: no table under {actual_heading}")
            return []
        start += 1
    if start >= len(lines):
        report.fail(f"{path}: no table under {actual_heading}")
        return []

    def cells(line: str) -> list[str]:
        return [cell.strip() for cell in line.strip().strip("|").split("|")]

    headers = cells(lines[start])
    start += 1
    if start < len(lines) and all(
        re.fullmatch(r":?-{3,}:?", cell.strip()) for cell in cells(lines[start])
    ):
        start += 1

    rows: list[dict[str, str]] = []
    while start < len(lines) and lines[start].lstrip().startswith("|"):
        values = cells(lines[start])
        if len(values) == len(headers):
            rows.append(dict(zip(headers, values)))
        else:
            report.fail(
                f"{path}: table row under {actual_heading} has {len(values)} cells, "
                f"expected {len(headers)}"
            )
        start += 1
    return rows


def version_field(path: Path, field: str) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [clean_cell(cell) for cell in line.strip().strip("|").split("|")]
        if len(cells) >= 2 and cells[0] == field:
            return cells[1].split()[0] if cells[1] else ""
    return ""


def task_status(path: Path) -> str:
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if line.strip() != "## 终态":
            continue
        for value in lines[index + 1 :]:
            value = clean_cell(value)
            if value:
                return value
    return ""


def section_field(
    path: Path,
    heading: str | tuple[str, ...],
    field: str,
) -> str:
    if not path.is_file():
        return ""
    lines = path.read_text(encoding="utf-8").splitlines()
    found = find_heading(lines, heading)
    if found is None:
        return ""
    heading_index, actual_heading = found
    start = heading_index + 1
    target_level = heading_level(actual_heading)
    for line in lines[start:]:
        level = heading_level(line)
        if level is not None and target_level is not None and level <= target_level:
            break
        match = re.match(
            rf"^\s*-\s*{re.escape(field)}\s*[：:]\s*(.*)$",
            line,
        )
        if match:
            return clean_cell(match.group(1))
    return ""


def yaml_like_fields(path: Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^([a-z_]+):\s*(.*)$", line.strip())
        if match:
            fields[match.group(1)] = clean_cell(match.group(2)).strip("\"'")
    return fields


def resolve_doc_link(root: Path, source: Path, cell: str) -> Path | None:
    target = markdown_link_target(cell) or clean_cell(cell)
    if not target or target.lower() in {"n/a", "none", "—"}:
        return None
    if target.startswith("docs/"):
        return (root / target).resolve()
    return (source.parent / target).resolve()


def validate_route(
    route_path: Path,
    *,
    spec_id: str,
    task_id: str,
    rail: str,
    workspace: str,
    owner: str,
    report: Report,
) -> None:
    route = yaml_like_fields(route_path)
    missing = sorted(
        key
        for key in ROUTE_REQUIRED_FIELDS
        if key not in route or route[key] == ""
    )
    if missing:
        report.fail(f"{route_path}: missing required Route v1 fields {missing}")

    expected_source = f"docs/specs/{spec_id}/tasks/{task_id}.md"
    expected_fields = {
        "route_version": ROUTE_VERSION,
        "route_id": f"{spec_id}/{task_id}",
        "spec": spec_id,
        "task": task_id,
        "rail": rail,
        "workspace": workspace,
        "source": expected_source,
        "owner": owner,
    }
    for key, expected in expected_fields.items():
        if key in route and route[key] != expected:
            report.fail(
                f"{route_path}: {key}='{route[key]}', expected '{expected}'"
            )

    for field in sorted(ROUTE_NATIVE_FIELDS & set(route)):
        value = route[field]
        if not value or value.lower() in {"none", "n/a"} or (
            value.startswith("<") and value.endswith(">")
        ):
            report.fail(
                f"{route_path}: optional native field {field} must be null "
                "or a real runtime ID"
            )

    for owner_kind, native_field in (
        ("user-thread", "thread_id"),
        ("subagent", "subagent_id"),
    ):
        prefix = f"{owner_kind}:"
        if not owner.startswith(prefix):
            continue
        expected_id = owner.removeprefix(prefix)
        if not expected_id or route.get(native_field) != expected_id:
            report.fail(
                f"{route_path}: owner '{owner}' requires "
                f"{native_field}='{expected_id}'"
            )


def ids(pattern: str, text: str) -> set[str]:
    return set(re.findall(pattern, text))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-docs.py <host-root>", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    report = Report()
    try:
        wip_cap = int(os.environ.get("WIP_CAP", "0"))
        if wip_cap < 0:
            raise ValueError
    except ValueError:
        report.fail("WIP_CAP must be a non-negative integer")
        wip_cap = 0

    print(f"== SDD skeleton ({root}) ==")
    required = [
        "AGENTS.md",
        "docs/README.md",
        "docs/reference/handoff.md",
        "docs/reference/claims.md",
        "docs/product/README.md",
        "docs/specs/_template/VERSION.md",
        "docs/specs/_template/context.md",
        "docs/specs/_template/requirements.md",
        "docs/specs/_template/technical-plan.md",
        "docs/specs/_template/scenario-spec.md",
        "docs/specs/_template/tasks.md",
        "docs/specs/_template/tasks/T-001.md",
        "docs/specs/_template/routes/T-001.next-rail.md",
        "docs/specs/_template/validation.md",
        "docs/specs/_template/evidence/README.md",
        "docs/operations/incidents/_template.md",
    ]
    for relative in required:
        path = root / relative
        if path.exists():
            report.ok(relative)
        else:
            report.fail(f"missing {relative}")

    print("== template contracts ==")
    markers = {
        "docs/specs/_template/VERSION.md": [
            "Delivery Target",
            "Requirements Lock",
            "Rail 属于对话 / Task",
        ],
        "docs/specs/_template/scenario-spec.md": [
            "ORACLE",
            "EFFECTIVE_CHANNEL",
            "FAILURE_ROUTE",
        ],
        "docs/specs/_template/tasks/T-001.md": [
            "写入边界",
            "Workspace Strategy",
            "最低证据",
            "所需 Claim ID",
            "终态",
        ],
        "docs/specs/_template/routes/T-001.next-rail.md": [
            "route_version:",
            "route_id:",
            "rail:",
            "source:",
            "workspace:",
            "owner:",
            "thread_id:",
            "subagent_id:",
            "goal_id:",
            "claims:",
        ],
        "docs/operations/incidents/_template.md": [
            "Production Verification",
            "production-restored",
            "回滚点",
        ],
    }
    for relative, expected in markers.items():
        path = root / relative
        text = path.read_text(encoding="utf-8") if path.is_file() else ""
        for marker in expected:
            if marker in text:
                report.ok(f"{relative}: {marker}")
            else:
                report.fail(f"{relative}: missing {marker}")

    version_template = root / "docs/specs/_template/VERSION.md"
    if version_template.is_file() and "Current Rail" in version_template.read_text(
        encoding="utf-8"
    ):
        report.fail("VERSION template must not store conversation-scoped Current Rail")

    print("== claims ==")
    claim_rows = parse_table(
        root / "docs/reference/claims.md", "# Active Claims", report
    )
    active_claims: dict[str, dict[str, str]] = {}
    active_resources: dict[str, str] = {}
    for row in claim_rows:
        claim_id = clean_cell(row.get("Claim", ""))
        if not claim_id:
            continue
        claim_type = clean_cell(row.get("Type", "")).lower()
        resource = clean_cell(row.get("Resource", ""))
        spec_id = clean_cell(row.get("Spec", ""))
        task_id = clean_cell(row.get("Task", ""))
        owner = clean_cell(row.get("Owner", ""))
        workspace = clean_cell(row.get("Workspace", "")).lower()
        status = clean_cell(row.get("Status", "")).lower()
        if claim_type not in CLAIM_TYPES:
            report.fail(
                f"claim {claim_id}: invalid Type '{claim_type}'; "
                "only 'resource' is allowed"
            )
        if status not in CLAIM_STATUSES:
            report.fail(f"claim {claim_id}: invalid Status '{status}'")
        if workspace not in WORKSPACES:
            report.fail(f"claim {claim_id}: invalid Workspace '{workspace}'")
        if not resource or not owner:
            report.fail(f"claim {claim_id}: Resource and Owner are required")
        task_path = root / f"docs/specs/{spec_id}/tasks/{task_id}.md"
        if not task_path.is_file():
            report.fail(f"claim {claim_id}: missing Task {spec_id}/{task_id}")
        if status == "active":
            if claim_id in active_claims:
                report.fail(f"duplicate active Claim ID {claim_id}")
            active_claims[claim_id] = row
            key = resource.casefold()
            if key in active_resources:
                report.fail(
                    f"claim conflict resource:{resource} "
                    f"({active_resources[key]} and {claim_id})"
                )
            active_resources[key] = claim_id
    report.ok(f"active claims={len(active_claims)}")

    print("== active work and Specs ==")
    handoff_path = root / "docs/reference/handoff.md"
    handoff_rows = parse_table(handoff_path, "## 活跃工作", report)
    active_rows = [row for row in handoff_rows if re.search(
        r"v\d{4}\.\d{2}-[a-z0-9-]+", row.get("Spec", "")
    )]
    if wip_cap and len(active_rows) > wip_cap:
        report.fail(f"active work {len(active_rows)} exceeds WIP_CAP={wip_cap}")
    else:
        report.ok(f"active rows={len(active_rows)}; WIP_CAP={wip_cap}")

    handoff_specs: set[str] = set()
    referenced_claims: set[str] = set()
    for row in active_rows:
        spec_match = re.search(r"v\d{4}\.\d{2}-[a-z0-9-]+", row.get("Spec", ""))
        assert spec_match
        spec_id = spec_match.group(0)
        handoff_specs.add(spec_id)
        task_id = clean_cell(row.get("Task", ""))
        rail = clean_cell(row.get("Rail", "")).lower()
        status = clean_cell(row.get("Status", "")).lower()
        owner = clean_cell(row.get("Owner", ""))
        workspace = clean_cell(row.get("Workspace", "")).lower()
        route_cell = row.get("Route", "")

        task_path = root / f"docs/specs/{spec_id}/tasks/{task_id}.md"
        if not re.fullmatch(r"T-\d{3}", task_id) or not task_path.is_file():
            report.fail(f"handoff {spec_id}: missing named Task '{task_id}'")
            continue
        if rail not in RAILS:
            report.fail(f"handoff {spec_id}/{task_id}: invalid Rail '{rail}'")
        if status not in TASK_STATUSES:
            report.fail(f"handoff {spec_id}/{task_id}: invalid Status '{status}'")
        actual_status = task_status(task_path)
        if actual_status != status:
            report.fail(
                f"handoff {spec_id}/{task_id}: status '{status}' "
                f"!= Work Order '{actual_status}'"
            )
        if not owner:
            report.fail(f"handoff {spec_id}/{task_id}: Owner is required")
        if workspace not in WORKSPACES:
            report.fail(
                f"handoff {spec_id}/{task_id}: invalid Workspace '{workspace}'"
            )

        route_path = resolve_doc_link(root, handoff_path, route_cell)
        if route_path is None or not route_path.is_file():
            report.fail(f"handoff {spec_id}/{task_id}: Route is missing")
        else:
            validate_route(
                route_path,
                spec_id=spec_id,
                task_id=task_id,
                rail=rail,
                workspace=workspace,
                owner=owner,
                report=report,
            )

        claim_cell = clean_cell(row.get("Claims", ""))
        claim_ids = [
            item for item in re.split(r"[,\s]+", claim_cell)
            if item and item.lower() not in {"n/a", "none", "—"}
        ]
        for claim_id in claim_ids:
            referenced_claims.add(claim_id)
            claim = active_claims.get(claim_id)
            if claim is None:
                report.fail(
                    f"handoff {spec_id}/{task_id}: Claim {claim_id} is not active"
                )
                continue
            if clean_cell(claim.get("Spec", "")) != spec_id or clean_cell(
                claim.get("Task", "")
            ) != task_id:
                report.fail(
                    f"handoff {spec_id}/{task_id}: Claim {claim_id} belongs elsewhere"
                )

    for claim_id in sorted(set(active_claims) - referenced_claims):
        report.fail(f"active Claim {claim_id} is not referenced by active handoff")

    for version_file in sorted((root / "docs/specs").glob("v*/VERSION.md")):
        spec_dir = version_file.parent
        spec_id = spec_dir.name
        status = version_field(version_file, "状态")
        if status not in VERSION_STATUSES:
            report.fail(f"{spec_id}: invalid Version status '{status}'")
            continue
        report.ok(f"{spec_id} Version status={status}")
        if "Current Rail" in version_file.read_text(encoding="utf-8"):
            report.fail(f"{spec_id}: Rail must not be stored on Version")

        if status not in {"archived", "cancelled"}:
            for filename in [
                "context.md",
                "requirements.md",
                "technical-plan.md",
                "scenario-spec.md",
                "tasks.md",
                "validation.md",
            ]:
                if not (spec_dir / filename).is_file():
                    report.fail(f"{spec_id}: missing {filename}")
        if status in ACTIVE_VERSION_STATUSES and spec_id not in handoff_specs:
            report.fail(f"{spec_id}: active Version missing from handoff")

        task_paths = sorted((spec_dir / "tasks").glob("T-*.md"))
        route_paths = sorted((spec_dir / "routes").glob("T-*.next-rail.md"))
        if status in ACTIVE_VERSION_STATUSES and not task_paths:
            report.fail(f"{spec_id}: active Version has no Task Work Order")

        indexed_tasks: set[str] = set()
        indexed_routes: set[str] = set()
        for row in parse_table(spec_dir / "tasks.md", "## Task Index", report):
            task_id = clean_cell(row.get("Task", ""))
            if not task_id:
                continue
            indexed_tasks.add(task_id)
            task_link = resolve_doc_link(root, spec_dir / "tasks.md", row.get(
                "Work Order", ""
            ))
            route_link = resolve_doc_link(root, spec_dir / "tasks.md", row.get(
                "Route", ""
            ))
            if task_link is None or not task_link.is_file():
                report.fail(f"{spec_id} Task Index: {task_id} Work Order missing")
            if route_link is None or not route_link.is_file():
                report.fail(f"{spec_id} Task Index: {task_id} Route missing")
            else:
                indexed_routes.add(task_id)

        actual_tasks = {path.stem for path in task_paths}
        actual_routes = {
            path.name.removesuffix(".next-rail.md") for path in route_paths
        }
        if actual_tasks != indexed_tasks:
            report.fail(
                f"{spec_id}: Task Index mismatch actual={sorted(actual_tasks)} "
                f"indexed={sorted(indexed_tasks)}"
            )
        if actual_routes != indexed_routes:
            report.fail(
                f"{spec_id}: Route Index mismatch actual={sorted(actual_routes)} "
                f"indexed={sorted(indexed_routes)}"
            )

        for task_path in task_paths:
            current = task_status(task_path)
            if current not in TASK_STATUSES:
                report.fail(f"{task_path}: invalid Task status '{current}'")
            mode_match = re.search(
                r"^\s*mode:\s*([a-z-]+)\s*$",
                task_path.read_text(encoding="utf-8"),
                re.MULTILINE,
            )
            if not mode_match or mode_match.group(1) not in WORKSPACES:
                report.fail(f"{task_path}: invalid or missing workspace.mode")
            if current == "passed":
                result = section_field(task_path, "## 实际证据", "结果")
                evidence = section_field(task_path, "## 实际证据", "证据路径")
                if not result or not evidence:
                    report.fail(
                        f"{task_path}: passed Task requires actual result and evidence path"
                    )

        scenario_ids: set[str] = set()
        requirement_ids: set[str] = set()
        if status in ACTIVE_VERSION_STATUSES:
            requirement_rows = parse_table(
                spec_dir / "requirements.md", "## Requirements", report
            )
            scenario_rows = parse_table(
                spec_dir / "scenario-spec.md", "## 场景矩阵", report
            )
            requirement_ids = {
                clean_cell(row.get("ID", ""))
                for row in requirement_rows
                if re.fullmatch(r"R-\d{3}", clean_cell(row.get("ID", "")))
            }
            scenario_ids = {
                clean_cell(row.get("ID", ""))
                for row in scenario_rows
                if re.fullmatch(r"SC-\d{3}", clean_cell(row.get("ID", "")))
            }
            scenario_requirements: dict[str, set[str]] = {}
            for row in scenario_rows:
                scenario_id = clean_cell(row.get("ID", ""))
                if scenario_id in scenario_ids:
                    scenario_requirements[scenario_id] = ids(
                        r"R-\d{3}", row.get("Requirement", "")
                    )
            mapped_requirements = set().union(
                *scenario_requirements.values()
            ) if scenario_requirements else set()
            for requirement_id in sorted(requirement_ids - mapped_requirements):
                report.fail(f"{spec_id}: {requirement_id} has no Scenario")
            for requirement_id in sorted(mapped_requirements - requirement_ids):
                report.fail(f"{spec_id}: Scenario references unknown {requirement_id}")
            task_text = "\n".join(
                path.read_text(encoding="utf-8") for path in task_paths
            )
            task_scenarios = ids(r"SC-\d{3}", task_text)
            for scenario_id in sorted(scenario_ids - task_scenarios):
                report.fail(f"{spec_id}: {scenario_id} is not assigned to a Task")

        delivery_target = version_field(version_file, "Delivery Target")
        requires_accounted_matrix = delivery_target in {
            "matrix-accounted",
            "acceptance-passed",
            "production-restored",
            "production-delivered",
            "user-accepted",
        } or status == "done"
        if requires_accounted_matrix:
            validation_path = spec_dir / "validation.md"
            if not requirement_ids:
                requirement_rows = parse_table(
                    spec_dir / "requirements.md", "## Requirements", report
                )
                requirement_ids = {
                    clean_cell(row.get("ID", ""))
                    for row in requirement_rows
                    if re.fullmatch(r"R-\d{3}", clean_cell(row.get("ID", "")))
                }
            if not scenario_ids:
                scenario_rows = parse_table(
                    spec_dir / "scenario-spec.md", "## 场景矩阵", report
                )
                scenario_ids = {
                    clean_cell(row.get("ID", ""))
                    for row in scenario_rows
                    if re.fullmatch(r"SC-\d{3}", clean_cell(row.get("ID", "")))
                }
            validation_rows = parse_table(
                validation_path,
                ("### 追踪矩阵", "## 追踪矩阵"),
                report,
            )
            validation_scenarios: set[str] = set()
            results: dict[str, str] = {}
            for row in validation_rows:
                scenario_id = clean_cell(row.get("Scenario", ""))
                if not re.fullmatch(r"SC-\d{3}", scenario_id):
                    continue
                validation_scenarios.add(scenario_id)
                requirement_id = clean_cell(row.get("Requirement", ""))
                task_id = clean_cell(row.get("Task", ""))
                implementation = clean_cell(row.get("Implementation", ""))
                evidence = clean_cell(row.get("Evidence", ""))
                result = clean_cell(row.get("Result", ""))
                results[scenario_id] = result
                if requirement_id not in requirement_ids:
                    report.fail(
                        f"{spec_id} validation {scenario_id}: unknown Requirement "
                        f"'{requirement_id}'"
                    )
                if task_id not in actual_tasks:
                    report.fail(
                        f"{spec_id} validation {scenario_id}: unknown Task '{task_id}'"
                    )
                if not implementation or not evidence:
                    report.fail(
                        f"{spec_id} validation {scenario_id}: "
                        "Implementation and Evidence are required"
                    )
                if result not in {"Pass", "Fail", "Blocked"}:
                    report.fail(
                        f"{spec_id} validation {scenario_id}: invalid Result '{result}'"
                    )
            for scenario_id in sorted(scenario_ids - validation_scenarios):
                report.fail(
                    f"{spec_id}: {scenario_id} missing from validation trace matrix"
                )

            classified_rows = parse_table(
                validation_path,
                ("### Fail / Blocked 分类", "## Fail / Blocked 分类"),
                report,
            )
            classified = {
                clean_cell(row.get("Scenario", "")): row
                for row in classified_rows
                if clean_cell(row.get("Scenario", ""))
            }
            for scenario_id, result in sorted(results.items()):
                if result not in {"Fail", "Blocked"}:
                    continue
                row = classified.get(scenario_id)
                if row is None:
                    report.fail(
                        f"{spec_id}: {scenario_id} {result} lacks classification"
                    )
                    continue
                if not clean_cell(row.get("分类", "")) or not clean_cell(
                    row.get("下一 Rail / Work Order", "")
                ):
                    report.fail(
                        f"{spec_id}: {scenario_id} classification lacks route"
                    )

            engineering_conclusion = ("### 工程结论", "## 结论")
            matrix = section_field(
                validation_path,
                engineering_conclusion,
                "Matrix",
            )
            acceptance = section_field(
                validation_path,
                engineering_conclusion,
                "Acceptance",
            )
            if matrix != "matrix-accounted":
                report.fail(
                    f"{spec_id}: accounted Delivery Target requires "
                    "Matrix=matrix-accounted"
                )
            if delivery_target in {
                "acceptance-passed",
                "production-delivered",
                "user-accepted",
            } or status == "done":
                non_pass = sorted(
                    scenario_id
                    for scenario_id, result in results.items()
                    if result != "Pass"
                )
                if non_pass:
                    report.fail(
                        f"{spec_id}: acceptance requires all Scenarios Pass; "
                        f"non-pass={non_pass}"
                    )
                if acceptance != "acceptance-passed":
                    report.fail(
                        f"{spec_id}: Delivery Target requires "
                        "Acceptance=acceptance-passed"
                    )

        if delivery_target in {"production-restored", "production-delivered"}:
            validation_path = spec_dir / "validation.md"
            required_production_fields = [
                "Deploy / rollback",
                "Health",
                "原始故障信号",
                "核心用户路径",
                "监控观察窗口",
                "回滚点",
            ]
            missing_fields = [
                field
                for field in required_production_fields
                if not section_field(
                    validation_path,
                    (
                        "### Production Verification（适用时）",
                        "## Production Verification（适用时）",
                    ),
                    field,
                )
            ]
            if missing_fields:
                report.fail(
                    f"{spec_id}: production Delivery Target missing evidence "
                    f"{missing_fields}"
                )

        if (spec_dir / "optional/scenario-spec.md").exists():
            report.fail(f"{spec_id}: scenario-spec.md must be at Spec root")

    if (root / "docs/product/regression/surfaces.json").is_file():
        try:
            json.loads(
                (root / "docs/product/regression/surfaces.json").read_text(
                    encoding="utf-8"
                )
            )
            report.ok("surfaces.json valid")
        except json.JSONDecodeError as exc:
            report.fail(f"invalid surfaces.json: {exc}")
    else:
        report.warn("no product regression surfaces catalog")

    print("---")
    print(
        f"errors={report.errors} warnings={report.warnings} "
        f"WIP_CAP={wip_cap}"
    )
    return 1 if report.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
