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
CLAIM_TYPES = {"task", "contract", "resource"}
CLAIM_STATUSES = {"active", "released"}


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


def markdown_link_target(value: str) -> str | None:
    match = re.search(r"\[[^\]]+\]\(([^)]+)\)", value)
    return match.group(1) if match else None


def parse_table(path: Path, heading: str, report: Report) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(heading) + 1
    except ValueError:
        report.fail(f"{path}: missing section {heading}")
        return []

    while start < len(lines) and not lines[start].lstrip().startswith("|"):
        if lines[start].startswith("## "):
            report.fail(f"{path}: no table under {heading}")
            return []
        start += 1
    if start >= len(lines):
        report.fail(f"{path}: no table under {heading}")
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
                f"{path}: table row under {heading} has {len(values)} cells, "
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
            "rail:",
            "source:",
            "workspace:",
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
    active_resources: dict[tuple[str, str], str] = {}
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
            report.fail(f"claim {claim_id}: invalid Type '{claim_type}'")
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
            key = (claim_type, resource)
            if key in active_resources:
                report.fail(
                    f"claim conflict {claim_type}:{resource} "
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
            route = yaml_like_fields(route_path)
            expected_source = f"docs/specs/{spec_id}/tasks/{task_id}.md"
            for key, expected in {
                "spec": spec_id,
                "task": task_id,
                "rail": rail,
                "workspace": workspace,
                "source": expected_source,
            }.items():
                if route.get(key) != expected:
                    report.fail(
                        f"{route_path}: {key}='{route.get(key)}', expected '{expected}'"
                    )

        claim_cell = clean_cell(row.get("Claims", ""))
        claim_ids = [
            item for item in re.split(r"[,\s]+", claim_cell)
            if item and item.lower() not in {"n/a", "none", "—"}
        ]
        for claim_id in claim_ids:
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
