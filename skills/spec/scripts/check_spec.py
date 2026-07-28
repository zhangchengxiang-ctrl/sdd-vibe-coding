#!/usr/bin/env python3
"""Spec static gates + run.md honesty + optional AGENTS readiness warnings.

Ships with the plugin (not only evals/) so conductors can refuse Build dispatch.
Usage:
  python3 check_spec.py <host-root> [<spec-id-or-path>]
  python3 check_spec.py <host-root> --all
  python3 check_spec.py <host-root> --agents-only

Exit: 0 ok, 1 errors, 2 usage.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LEGACY_NAMES = {
    "context.md",
    "requirements.md",
    "tasks.md",
    "validation.md",
    "scenario-spec.md",
    "technical-plan.md",
    "spec-run.md",
}
CORE_FILES = ("VERSION.md", "contract.md", "tests.md", "plan.md", "run.md")
FACT_HEADERS = {
    "入口",
    "actor",
    "业务实体 / 表关系",
    "可信路径如何派生",
    "代码调用点",
    "越权反例",
    "证据级",
}
# tolerate minor header variants
FACT_HEADER_ALIASES = {
    "业务实体 / 表关系（含 FK）": "业务实体 / 表关系",
    "业务实体/表关系": "业务实体 / 表关系",
}
EMPTYISH = {"", "—", "-", "n/a", "N/A", "TODO", "TBD", "…", "..."}


class Report:
    def __init__(self) -> None:
        self.errors = 0
        self.warnings = 0

    def ok(self, msg: str) -> None:
        print(f"OK: {msg}")

    def fail(self, msg: str) -> None:
        print(f"ERROR: {msg}", file=sys.stderr)
        self.errors += 1

    def warn(self, msg: str) -> None:
        print(f"WARN: {msg}", file=sys.stderr)
        self.warnings += 1


def clean(value: str) -> str:
    return value.strip().replace("`", "").replace("**", "")


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def resolve_sdd_root(host: Path) -> Path:
    agents = host / "AGENTS.md"
    if agents.is_file():
        for line in agents.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\s*-\s*SDD docs root:\s*(.+?)\s*$", line)
            if m:
                rel = m.group(1).strip().strip("`")
                return (host / rel).resolve()
    return (host / "docs").resolve()


def parse_md_table_after(text: str, heading_substr: str) -> tuple[list[str], list[dict[str, str]]]:
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("#") and heading_substr in line:
            start = i + 1
            break
    if start is None:
        return [], []
    while start < len(lines) and not lines[start].lstrip().startswith("|"):
        if lines[start].startswith("#"):
            return [], []
        start += 1
    if start >= len(lines):
        return [], []
    headers = [clean(h) for h in cells(lines[start])]
    start += 1
    if start < len(lines) and all(
        re.fullmatch(r":?-{3,}:?", c.strip()) for c in cells(lines[start])
    ):
        start += 1
    rows: list[dict[str, str]] = []
    while start < len(lines) and lines[start].lstrip().startswith("|"):
        vals = cells(lines[start])
        if len(vals) == len(headers):
            rows.append({headers[i]: clean(vals[i]) for i in range(len(headers))})
        start += 1
    return headers, rows


def row_nonempty(row: dict[str, str], keys: list[str] | None = None) -> bool:
    use = keys or list(row.keys())
    for k in use:
        v = clean(row.get(k, ""))
        if v and v not in EMPTYISH and not v.startswith("Verified /"):
            # template placeholder "Verified / Unverified" alone is emptyish for evidence
            if v in {"Verified / Unverified", "Pass / Fail / Blocked"}:
                continue
            return True
    return False


def is_template_dir(spec_dir: Path) -> bool:
    return spec_dir.name == "_template"


def detect_has_ui(contract: str, plan: str, tests: str) -> bool:
    blob = f"{contract}\n{plan}\n{tests}".lower()
    if re.search(r"\bux:\s*n/a\b", blob) or "无 ui" in blob or "pure backend" in blob:
        return False
    ui_hits = (
        "浏览器",
        "browser",
        "frontend",
        "前端",
        "页面",
        "ui ",
        " ux",
        "v2",
        "scenario",
        "用户可见",
    )
    return any(h in blob for h in ui_hits)


def check_legacy_skeleton(spec_dir: Path, report: Report) -> None:
    legacy = [n for n in LEGACY_NAMES if (spec_dir / n).is_file()]
    has_contract = (spec_dir / "contract.md").is_file()
    if legacy and not has_contract:
        report.fail(
            f"{spec_dir.name}: legacy Spec skeleton {legacy} without contract.md "
            "(old context/requirements/tasks — reject)"
        )
    elif legacy and has_contract:
        report.warn(f"{spec_dir.name}: legacy files present alongside core: {legacy}")


def check_core_files(spec_dir: Path, report: Report, *, structure_only: bool) -> dict[str, str]:
    texts: dict[str, str] = {}
    for name in CORE_FILES:
        path = spec_dir / name
        if not path.is_file():
            report.fail(f"{spec_dir.name}: missing {name}")
            texts[name] = ""
        else:
            texts[name] = read_text(path)
            if not structure_only:
                report.ok(f"{spec_dir.name}: has {name}")
    return texts


def check_fact_mapping(spec_dir: Path, contract: str, report: Report, *, structure_only: bool) -> None:
    if "入口事实映射" not in contract:
        report.fail(f"{spec_dir.name}/contract.md: missing 入口事实映射 section")
        return
    headers, rows = parse_md_table_after(contract, "入口事实映射")
    if not headers:
        report.fail(f"{spec_dir.name}/contract.md: no table under 入口事实映射")
        return
    normalized = [FACT_HEADER_ALIASES.get(h, h) for h in headers]
    missing = FACT_HEADERS - set(normalized)
    if missing:
        report.fail(f"{spec_dir.name}/contract.md: fact-map missing columns {sorted(missing)}")
        return
    report.ok(f"{spec_dir.name}: fact-map columns ok")
    if structure_only:
        return
    filled = [r for r in rows if row_nonempty(r, ["入口", "actor", "代码调用点", "证据级"])]
    if not filled:
        report.fail(f"{spec_dir.name}/contract.md: fact-map has no filled rows")
        return
    for i, row in enumerate(filled, 1):
        ev = clean(row.get("证据级", ""))
        if ev not in {"Verified", "Unverified", "Assumption"}:
            report.fail(
                f"{spec_dir.name}/contract.md: fact-map row {i} evidence must be "
                f"Verified|Unverified|Assumption (got '{ev}')"
            )
    report.ok(f"{spec_dir.name}: fact-map has {len(filled)} filled row(s)")


def check_requirements_unverified(spec_dir: Path, contract: str, report: Report, *, structure_only: bool) -> list[dict[str, str]]:
    headers, rows = parse_md_table_after(contract, "Requirements")
    if not headers:
        if not structure_only:
            report.fail(f"{spec_dir.name}/contract.md: missing Requirements table")
        return []
    if structure_only:
        return rows
    real = [
        r
        for r in rows
        if clean(r.get("ID", "")) and clean(r.get("ID", "")) not in EMPTYISH
    ]
    if not real:
        report.fail(f"{spec_dir.name}/contract.md: Requirements table has no IDs")
        return []
    for row in real:
        rid = clean(row.get("ID", ""))
        pri = clean(row.get("优先级", "")).upper()
        ev = clean(row.get("证据级", ""))
        if pri == "P0" and ev in {"Unverified", "Assumption"}:
            report.fail(
                f"{spec_dir.name}: {rid} is P0 with evidence {ev} "
                "(Unverified must not be P0/Lock)"
            )
        tests = clean(row.get("Tests", ""))
        if pri == "P0" and not tests:
            report.fail(f"{spec_dir.name}: {rid} P0 missing Tests mapping")
    report.ok(f"{spec_dir.name}: Requirements rows={len(real)}")
    return real


def extract_test_bodies(tests: str) -> dict[str, str]:
    bodies: dict[str, str] = {}
    parts = re.split(r"(?m)^## (T-\d+)\b", tests)
    # parts: [preamble, id1, body1, id2, body2, ...]
    for i in range(1, len(parts), 2):
        tid = parts[i]
        body = parts[i + 1] if i + 1 < len(parts) else ""
        bodies[tid] = body
    return bodies


def check_tests(
    spec_dir: Path,
    tests: str,
    req_rows: list[dict[str, str]],
    report: Report,
    *,
    structure_only: bool,
) -> None:
    if "### Given" not in tests or "### When" not in tests:
        report.fail(f"{spec_dir.name}/tests.md: missing Given/When headings")
        return
    if "### Then" not in tests and "### Then（Oracle）" not in tests:
        report.fail(f"{spec_dir.name}/tests.md: missing Then（Oracle）")
        return
    report.ok(f"{spec_dir.name}: tests.md has Given/When/Then markers")
    if structure_only:
        return

    _, index_rows = parse_md_table_after(tests, "索引")
    index_ids = {
        clean(r.get("ID", ""))
        for r in index_rows
        if clean(r.get("ID", "")) and clean(r.get("ID", "")) not in EMPTYISH
    }
    bodies = extract_test_bodies(tests)
    if not index_ids:
        report.fail(f"{spec_dir.name}/tests.md: index has no Test IDs")
        return
    for tid in sorted(index_ids):
        if tid not in bodies:
            report.fail(f"{spec_dir.name}/tests.md: index {tid} has no ## {tid} body")
            continue
        body = bodies[tid]
        for need in ("### Given", "### When"):
            if need not in body:
                report.fail(f"{spec_dir.name}/tests.md: {tid} missing {need}")
        if "### Then" not in body:
            report.fail(f"{spec_dir.name}/tests.md: {tid} missing ### Then")
        # empty placeholders: Given section should have more than labels only
        given = re.search(r"### Given\n(.*?)(?:\n### |\n## |\Z)", body, re.S)
        if given and not re.search(r"[^\s\-：:].{3,}", given.group(1)):
            report.warn(f"{spec_dir.name}/tests.md: {tid} Given looks empty")

    # P0 success + failure/permission
    p0_ids = [
        clean(r.get("ID", ""))
        for r in req_rows
        if clean(r.get("优先级", "")).upper() == "P0"
    ]
    for rid in p0_ids:
        mapped = [
            r
            for r in index_rows
            if rid in clean(r.get("R", "")) or rid in clean(r.get("Requirement", ""))
        ]
        if not mapped:
            # also allow Tests column from requirements
            continue
        types = " ".join(clean(r.get("Type", "")).lower() for r in mapped)
        has_success = "success" in types
        has_fail = "fail" in types or "permission" in types
        if not has_success or not has_fail:
            report.fail(
                f"{spec_dir.name}: P0 {rid} needs ≥1 success and ≥1 failure/permission "
                f"in tests index (types={types!r})"
            )
    # Cross-check Requirements.Tests column
    for row in req_rows:
        if clean(row.get("优先级", "")).upper() != "P0":
            continue
        rid = clean(row.get("ID", ""))
        listed = re.findall(r"T-\d+", clean(row.get("Tests", "")))
        if not listed:
            continue
        for tid in listed:
            if tid not in index_ids:
                report.fail(f"{spec_dir.name}: {rid} lists {tid} missing from tests index")
        # type coverage via index rows for listed tests
        mapped = [r for r in index_rows if clean(r.get("ID", "")) in listed]
        types = " ".join(clean(r.get("Type", "")).lower() for r in mapped)
        if "success" not in types or not (
            "fail" in types or "permission" in types
        ):
            report.fail(
                f"{spec_dir.name}: P0 {rid} mapped tests lack success+failure/permission"
            )
    report.ok(f"{spec_dir.name}: tests index bodies checked ({len(index_ids)} ids)")


def check_plan_architecture(
    spec_dir: Path,
    plan: str,
    has_ui: bool,
    report: Report,
    *,
    structure_only: bool,
    checklist_dir: Path,
) -> None:
    if "## 架构与设计边界" not in plan:
        report.fail(f"{spec_dir.name}/plan.md: missing ## 架构与设计边界")
        return
    report.ok(f"{spec_dir.name}: plan has 架构与设计边界")
    if structure_only:
        return

    # Extract section body until next ##
    m = re.search(r"## 架构与设计边界\n(.*?)(?=\n## |\Z)", plan, re.S)
    body = m.group(1) if m else ""
    checklist_path = checklist_dir / "plan-architecture.checklist.json"
    items = []
    if checklist_path.is_file():
        items = json.loads(checklist_path.read_text(encoding="utf-8")).get("items", [])
    prompts = [it.get("prompt", "") for it in items] or [
        "边界",
        "C4",
        "ADR",
        "UX",
        "Unverified",
    ]
    filled = 0
    for line in body.splitlines():
        line = line.strip()
        if not line.startswith("-"):
            continue
        # "- 边界：沿用现有" → need content after colon
        if "：" in line or ":" in line:
            val = re.split(r"[：:]", line, maxsplit=1)[1].strip()
            if val and val not in EMPTYISH:
                filled += 1
    if filled == 0:
        report.fail(
            f"{spec_dir.name}/plan.md: 架构与设计边界 has no filled bullets "
            "(write 沿用现有边界，无架构差量 — or full checklist)"
        )
    else:
        report.ok(f"{spec_dir.name}: architecture boundary bullets filled ({filled})")

    if has_ui:
        ui_path = checklist_dir / "ui-surface.checklist.json"
        # Soft: plan should mention UX/视觉 or N/A
        if not re.search(r"UX|视觉|N/A|无 UI", body, re.I):
            report.warn(
                f"{spec_dir.name}/plan.md: has_ui suspected but UX/视觉/N/A not mentioned "
                f"(see {ui_path.name if ui_path.is_file() else 'ui-surface checklist'})"
            )


def check_run_honesty(spec_dir: Path, run: str, report: Report, *, structure_only: bool) -> None:
    if structure_only or not run:
        return
    status = ""
    m = re.search(r"-\s*状态：\s*`?([^`|\n]+)`?", run)
    if m:
        status = clean(m.group(1)).split("|")[0].strip()
    acceptance = ""
    m2 = re.search(r"-\s*Acceptance：\s*`?([^`|\n]+)`?", run)
    if m2:
        acceptance = clean(m2.group(1)).split("|")[0].strip()
    deliver = ""
    m3 = re.search(r"是否可以交付：\s*`?([^`|\n]+)`?", run)
    if m3:
        deliver = clean(m3.group(1)).split("|")[0].strip()

    # Parse matrix results
    _, matrix = parse_md_table_after(run, "追踪矩阵")
    results = [
        clean(r.get("Result", "")).lower()
        for r in matrix
        if clean(r.get("Test", "")) not in EMPTYISH
    ]
    bad = [r for r in results if r in {"fail", "blocked"}]
    claimed_pass = (
        "acceptance-passed" in status
        or acceptance == "acceptance-passed"
        or deliver == "可交付"
    )
    if claimed_pass and bad:
        report.fail(
            f"{spec_dir.name}/run.md: claims acceptance/可交付 but matrix has "
            f"Fail/Blocked ({len(bad)})"
        )
    elif claimed_pass:
        report.ok(f"{spec_dir.name}: run honesty ok (no Fail/Blocked vs acceptance)")

    # UX N/A vs evidence — only when acceptance claimed and UI tests present
    if claimed_pass and "UX: N/A" not in run and "ux: n/a" not in run.lower():
        evidence_cells = [
            clean(r.get("Evidence", ""))
            for r in matrix
            if clean(r.get("Test", "")) not in EMPTYISH
        ]
        if evidence_cells and all(e in EMPTYISH for e in evidence_cells):
            report.warn(
                f"{spec_dir.name}/run.md: acceptance claimed but Evidence column empty"
            )


def check_agents_readiness(host: Path, report: Report) -> None:
    agents = host / "AGENTS.md"
    if not agents.is_file():
        report.warn("AGENTS.md missing (scaffold recommended)")
        return
    text = agents.read_text(encoding="utf-8")
    # readiness table rows
    for capability in (
        "本地启动与定向验证",
        "用户可见页面验收",
    ):
        if capability not in text:
            report.warn(f"AGENTS.md: readiness row '{capability}' not found")
            continue
        # crude: look for line containing capability and missing/ready
        for line in text.splitlines():
            if capability in line and "|" in line:
                low = line.lower()
                if "missing" in low:
                    report.warn(f"AGENTS.md: '{capability}' is missing — Verify/UI may Block")
                elif "ready" in low:
                    report.ok(f"AGENTS.md: '{capability}' ready")
                break
    # empty command block
    if re.search(r"```bash\n(?:#.*\n){2,}```", text) or "# 启动：\n# 定向测试：" in text:
        # check if any non-comment command-like line exists
        in_bash = False
        has_cmd = False
        for line in text.splitlines():
            if line.strip().startswith("```"):
                in_bash = not in_bash
                continue
            if in_bash and line.strip() and not line.strip().startswith("#"):
                has_cmd = True
                break
        if not has_cmd:
            report.warn("AGENTS.md: 常用命令 block has no real commands (empty slots)")


def find_spec_dirs(docs: Path, spec_arg: str | None, all_specs: bool) -> list[Path]:
    specs_root = docs / "specs"
    if spec_arg:
        p = Path(spec_arg)
        if not p.is_absolute():
            cand = specs_root / spec_arg
            if cand.is_dir():
                return [cand.resolve()]
            cand2 = Path.cwd() / spec_arg
            if cand2.is_dir():
                return [cand2.resolve()]
            return [p.resolve()]
        return [p.resolve()]
    if not specs_root.is_dir():
        return []
    dirs = sorted(
        d
        for d in specs_root.iterdir()
        if d.is_dir() and not d.name.startswith(".")
    )
    if all_specs:
        return [d for d in dirs if d.name != "_template"]
    # default: all non-template; if none, check template structure-only
    real = [d for d in dirs if d.name != "_template"]
    if real:
        return real
    tmpl = specs_root / "_template"
    return [tmpl] if tmpl.is_dir() else []


def check_spec_dir(
    spec_dir: Path,
    report: Report,
    checklist_dir: Path,
) -> None:
    structure_only = is_template_dir(spec_dir)
    label = f"{spec_dir.name} ({'structure-only' if structure_only else 'full'})"
    print(f"== Spec {label} ==")
    check_legacy_skeleton(spec_dir, report)
    texts = check_core_files(spec_dir, report, structure_only=structure_only)
    contract, tests, plan, run = (
        texts.get("contract.md", ""),
        texts.get("tests.md", ""),
        texts.get("plan.md", ""),
        texts.get("run.md", ""),
    )
    check_fact_mapping(spec_dir, contract, report, structure_only=structure_only)
    req_rows = check_requirements_unverified(
        spec_dir, contract, report, structure_only=structure_only
    )
    check_tests(spec_dir, tests, req_rows, report, structure_only=structure_only)
    has_ui = detect_has_ui(contract, plan, tests)
    check_plan_architecture(
        spec_dir,
        plan,
        has_ui,
        report,
        structure_only=structure_only,
        checklist_dir=checklist_dir,
    )
    check_run_honesty(spec_dir, run, report, structure_only=structure_only)


def main() -> int:
    parser = argparse.ArgumentParser(description="SDD Spec static + honesty gates")
    parser.add_argument("host", help="Host repo root")
    parser.add_argument(
        "spec",
        nargs="?",
        help="Spec id under <SDD root>/specs/ or path to Spec dir",
    )
    parser.add_argument("--all", action="store_true", help="Check all non-template Specs")
    parser.add_argument(
        "--agents-only",
        action="store_true",
        help="Only AGENTS readiness warnings",
    )
    parser.add_argument(
        "--skip-agents",
        action="store_true",
        help="Skip AGENTS readiness warnings",
    )
    args = parser.parse_args()
    host = Path(args.host).resolve()
    if not host.is_dir():
        print(f"ERROR: not a directory: {host}", file=sys.stderr)
        return 2

    report = Report()
    script_dir = Path(__file__).resolve().parent
    checklist_dir = (
        script_dir.parent.parent / "vibe-coding/references/design-standards"
    ).resolve()

    if not args.skip_agents or args.agents_only:
        print("== AGENTS readiness ==")
        check_agents_readiness(host, report)
    if args.agents_only:
        print(f"---\nerrors={report.errors} warnings={report.warnings}")
        return 1 if report.errors else 0

    docs = resolve_sdd_root(host)
    if not docs.is_dir():
        report.fail(f"SDD docs root missing: {docs}")
        print(f"---\nerrors={report.errors} warnings={report.warnings}")
        return 1

    print(f"== SDD docs root: {docs} ==")
    spec_dirs = find_spec_dirs(docs, args.spec, args.all)
    if not spec_dirs:
        report.warn("no Spec dirs to check (only _template empty tree?)")
    for d in spec_dirs:
        if not d.is_dir():
            report.fail(f"Spec path not a directory: {d}")
            continue
        check_spec_dir(d, report, checklist_dir)

    print(f"---\nerrors={report.errors} warnings={report.warnings}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
