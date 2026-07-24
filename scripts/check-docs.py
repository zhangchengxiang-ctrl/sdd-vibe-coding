#!/usr/bin/env python3
"""Validate Spec structure, traceability, handoff, and shared-resource claims."""

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
SPEC_RUN_STATES = {"ready", "building", "unit-testing", "verifying", "repairing", "blocked", "acceptance-passed"}
SPEC_RUN_MODES = {"build", "verify", "repair"}
WORKSPACES = {"local", "codex-worktree", "git-worktree", "blocked", "n/a"}
CLAIM_TYPES = {"resource"}
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


def inline_list(value: str) -> set[str]:
    value = clean_cell(value)
    if not value or value.lower() in {"[]", "n/a", "none", "—"}:
        return set()
    if value.startswith("[") and value.endswith("]"):
        value = value[1:-1]
    return {
        item.strip("\"'")
        for item in re.split(r"[,\s]+", value)
        if item.strip("\"'")
    }


def validate_unique_ids(
    rows: list[dict[str, str]],
    *,
    column: str,
    pattern: str,
    label: str,
    context: str,
    report: Report,
    required: bool = False,
) -> set[str]:
    found: set[str] = set()
    for row in rows:
        value = clean_cell(row.get(column, ""))
        if not value:
            continue
        if not re.fullmatch(pattern, value):
            report.fail(f"{context}: invalid {label} ID '{value}'")
            continue
        if value in found:
            report.fail(f"{context}: duplicate {label} ID '{value}'")
        found.add(value)
    if required and not found:
        report.fail(f"{context}: at least one valid {label} ID is required")
    return found


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
            "Rail 属于对话，不属于 Version",
        ],
        "docs/specs/_template/scenario-spec.md": [
            "ORACLE",
            "EFFECTIVE_CHANNEL",
            "FAILURE_ROUTE",
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
        if not (root / f"docs/specs/{spec_id}/VERSION.md").is_file():
            report.fail(f"claim {claim_id}: missing Spec {spec_id}")
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
        if not (root / f"docs/specs/{spec_id}/VERSION.md").is_file():
            report.fail(f"handoff {spec_id}: points to a nonexistent Spec")
        run_state = clean_cell(row.get("Spec Run 状态", "")).lower()
        mode = clean_cell(row.get("当前模式", "")).lower()
        owner = clean_cell(row.get("Owner", ""))
        workspace = clean_cell(row.get("Workspace", "")).lower()
        if run_state not in SPEC_RUN_STATES:
            report.fail(f"handoff {spec_id}: invalid Spec Run state '{run_state}'")
        if mode not in SPEC_RUN_MODES:
            report.fail(f"handoff {spec_id}: invalid Spec Run mode '{mode}'")
        if not owner:
            report.fail(f"handoff {spec_id}: Owner is required")
        if workspace not in WORKSPACES:
            report.fail(
                f"handoff {spec_id}: invalid Workspace '{workspace}'"
            )

        claim_cell = clean_cell(row.get("Claims", ""))
        claim_ids = inline_list(claim_cell)
        for claim_id in claim_ids:
            referenced_claims.add(claim_id)
            claim = active_claims.get(claim_id)
            if claim is None:
                report.fail(
                    f"handoff {spec_id}: Claim {claim_id} is not active"
                )
                continue
            if clean_cell(claim.get("Spec", "")) != spec_id:
                report.fail(
                    f"handoff {spec_id}: Claim {claim_id} belongs elsewhere"
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
                "spec-run.md",
                "validation.md",
            ]:
                if not (spec_dir / filename).is_file():
                    report.fail(f"{spec_id}: missing {filename}")
        if status in ACTIVE_VERSION_STATUSES and spec_id not in handoff_specs:
            report.fail(f"{spec_id}: active Version missing from handoff")

        scenario_ids: set[str] = set()
        requirement_ids: set[str] = set()
        if status in ACTIVE_VERSION_STATUSES:
            requirement_rows = parse_table(
                spec_dir / "requirements.md", "## Requirements", report
            )
            scenario_rows = parse_table(
                spec_dir / "scenario-spec.md", "## 场景矩阵", report
            )
            requirement_ids = validate_unique_ids(
                requirement_rows,
                column="ID",
                pattern=r"R-\d{3}",
                label="Requirement",
                context=spec_id,
                report=report,
                required=True,
            )
            scenario_ids = validate_unique_ids(
                scenario_rows,
                column="ID",
                pattern=r"SC-\d{3}",
                label="Scenario",
                context=spec_id,
                report=report,
                required=True,
            )
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
                implementation = clean_cell(row.get("Implementation", ""))
                evidence = clean_cell(row.get("Evidence", ""))
                result = clean_cell(row.get("Result", ""))
                results[scenario_id] = result
                if requirement_id not in requirement_ids:
                    report.fail(
                        f"{spec_id} validation {scenario_id}: unknown Requirement "
                        f"'{requirement_id}'"
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
                    row.get("统一 Repair 组 / 外部阻塞", "")
                ):
                    report.fail(
                        f"{spec_id}: {scenario_id} classification lacks next step"
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
