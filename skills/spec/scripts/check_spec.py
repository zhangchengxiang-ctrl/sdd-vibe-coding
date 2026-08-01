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


def detect_ui_surface(contract: str, plan: str, tests: str) -> str | None:
    """Return product|consumer|n/a if declared; else None."""
    blob = f"{contract}\n{plan}\n{tests}"
    m = re.search(
        r"UI\s*surface\s*[:：]\s*`?(product|consumer|n/a)`?",
        blob,
        flags=re.IGNORECASE,
    )
    if m:
        return m.group(1).lower()
    m = re.search(
        r"(?m)^\s*[-*]?\s*`?surface`?\s*[:：]\s*`?(product|consumer|n/a)`?",
        blob,
        flags=re.IGNORECASE,
    )
    if m:
        return m.group(1).lower()
    return None


def detect_page_kind(contract: str, plan: str, tests: str) -> str | None:
    """Return page_kind or motif (equivalent for consumer)."""
    blob = f"{contract}\n{plan}\n{tests}"
    m = re.search(
        r"page_kind\s*[:：]\s*`?([a-z][a-z0-9_-]*)`?",
        blob,
        flags=re.IGNORECASE,
    )
    if m:
        return m.group(1).lower()
    m = re.search(
        r"\bmotif\s*[:：]\s*`?([a-z][a-z0-9_-]*)`?",
        blob,
        flags=re.IGNORECASE,
    )
    return m.group(1).lower() if m else None


def detect_design_read(contract: str, plan: str, tests: str) -> bool:
    """True if Design Read line or equivalent is present."""
    blob = f"{contract}\n{plan}\n{tests}"
    if re.search(r"Reading\s+this\s+as\s*:", blob, flags=re.IGNORECASE):
        return True
    if re.search(r"Design\s*Read\s*[:：]\s*\S+", blob, flags=re.IGNORECASE):
        return True
    return False


def detect_job_brief(contract: str, plan: str, tests: str) -> bool:
    """True if Job Brief block or Job+Consequence fields are present (product-judgment)."""
    blob = f"{contract}\n{plan}\n{tests}"
    if re.search(r"Job\s*Brief\s*[:：]", blob, flags=re.IGNORECASE):
        return True
    if re.search(r"(?m)^#{1,4}\s*Job\s*Brief\b", blob, flags=re.IGNORECASE):
        return True
    # Compact: Job: … plus Consequence/后果 somewhere in the same docs
    has_job = re.search(
        r"(?m)^\s*[-*]?\s*\*?\*?Job\*?\*?\s*[:：]\s*\S+",
        blob,
        flags=re.IGNORECASE,
    )
    has_consequence = re.search(
        r"(?m)^\s*[-*]?\s*\*?\*?(Consequence|后果|Desired\s*outcome|期望结果)\*?\*?\s*[:：]\s*\S+",
        blob,
        flags=re.IGNORECASE,
    )
    return bool(has_job and has_consequence)


def detect_anchor(contract: str, plan: str, tests: str) -> bool:
    blob = f"{contract}\n{plan}\n{tests}"
    if re.search(r"\banchor\s*[:：]\s*\S+", blob, flags=re.IGNORECASE):
        # reject hollow anchors
        if re.search(
            r"anchor\s*[:：]\s*.*(现代|干净|简洁|高级|sleek|clean|modern)\s*$",
            blob,
            flags=re.IGNORECASE | re.MULTILINE,
        ):
            return False
        return True
    return False


WEAK_ORACLE_PHRASES = (
    "能打开",
    "页面打开",
    "页面正常",
    "有数据",
    "列表有数据",
    "表格出现",
    "能看到列表",
    "正常显示",
    "渲染成功",
    "加载成功",
    "可以滚动",
    "冒烟通过",
    "smoke pass",
    "smoke passed",
    "page loads",
    "page load",
    "works",
)

DATA_SURFACE_RE = re.compile(
    r"page_kind\s*[:：]\s*`?(list|dashboard)`?"
    r"|\bmotif\s*[:：]\s*`?(list|dashboard)`?"
    r"|分页|无限滚动|infinite[\s_-]?scroll|load[\s_-]?more"
    r"|排序|筛选|offset|cursor[\s_-]?pag",
    re.IGNORECASE,
)

FALSIFY_HINT_RE = re.compile(
    r"offset|cursor|has_more|order_by|sort_by|排序参数|主键"
    r"|响应不同|可区分|api-diff|network-har|二次请求|下一页"
    r"|page\s*[#:]?\s*2|不同.{0,8}(rows?|批|页|键)|两态|证伪",
    re.IGNORECASE,
)

SMOKE_ONLY_RE = re.compile(
    r"(?:window[\s_-]?smoke|dev-ui-window-smoke|smoke[\s_-]?latest"
    r"|/health\b|health[\s_-]?check"
    r"|kind\s*=\s*(?:window-smoke|health)\b)",
    re.IGNORECASE,
)

STRONG_KIND_RE = re.compile(
    r"kind\s*=\s*(?:api-diff|network-har|browser-job|unit|integration)\b",
    re.IGNORECASE,
)


def extract_then_body(test_body: str) -> str:
    m = re.search(
        r"### Then(?:（Oracle）)?\n(.*?)(?:\n### |\n## |\Z)",
        test_body,
        re.S,
    )
    return m.group(1) if m else ""


def then_is_weak(then_text: str) -> bool:
    """True when Then has no distinguishing assertion beyond weak phrases."""
    if FALSIFY_HINT_RE.search(then_text):
        return False
    substantive = 0
    for raw in then_text.splitlines():
        line = raw.strip()
        if not line:
            continue
        line = re.sub(
            r"^[-*]\s*(用户可见|副作用[^：:\n]*)[：:]\s*",
            "",
            line,
        ).strip()
        if not line:
            continue
        tmp = line
        for phrase in WEAK_ORACLE_PHRASES:
            tmp = re.sub(re.escape(phrase), "", tmp, flags=re.IGNORECASE)
        for filler in ("列表", "页面", "表格", "用户", "可见", "应当", "应该", "显示"):
            tmp = tmp.replace(filler, "")
        tmp = re.sub(r"[\s，。、；;:：\-_/|（）()【】\[\]`<>「」]+", "", tmp)
        if len(tmp) >= 2:
            substantive += 1
    return substantive == 0


def detect_data_surface(contract: str, plan: str, tests: str) -> bool:
    blob = f"{contract}\n{plan}\n{tests}"
    pk = detect_page_kind(contract, plan, tests)
    if pk in {"list", "dashboard"}:
        return True
    return bool(DATA_SURFACE_RE.search(blob))


def evidence_is_smoke_only(evidence: str) -> bool:
    """Pass-quality evidence that is only smoke/health (no strong kind)."""
    e = clean(evidence)
    if e in EMPTYISH:
        return False
    if STRONG_KIND_RE.search(e):
        return False
    if SMOKE_ONLY_RE.search(e):
        return True
    # bare smoke json / smoke path without kind=
    if re.search(r"(?i)smoke", e) and not STRONG_KIND_RE.search(e):
        if re.search(r"(?i)\.json\b|window|dev-ui|/health\b", e):
            return True
    return False


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
    contract: str = "",
    plan: str = "",
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
        then = extract_then_body(body)
        if then and then_is_weak(then):
            report.fail(
                f"{spec_dir.name}/tests.md: {tid} Then is weak Oracle "
                "(only '能打开/有数据/冒烟通过' class — see oracle-strength.md)"
            )

    # Data-surface: at least one Then must carry falsify hints
    if detect_data_surface(contract, plan, tests):
        all_thens = "\n".join(extract_then_body(b) for b in bodies.values())
        if not FALSIFY_HINT_RE.search(all_thens):
            report.fail(
                f"{spec_dir.name}/tests.md: data-surface Spec needs ≥1 Then with "
                "falsify assertion (two offsets / order_by / distinguishable rows — "
                "see oracle-strength.md)"
            )
        else:
            report.ok(f"{spec_dir.name}: data-surface falsify hint present")

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
        if not re.search(r"UX|视觉|N/A|无 UI|surface", body, re.I):
            report.warn(
                f"{spec_dir.name}/plan.md: has_ui suspected but UX/视觉/surface/N/A not mentioned "
                f"(see {ui_path.name if ui_path.is_file() else 'ui-surface checklist'})"
            )


def check_ui_surface(
    spec_dir: Path,
    contract: str,
    plan: str,
    tests: str,
    *,
    has_ui: bool,
    report: Report,
    structure_only: bool,
) -> None:
    if structure_only or not has_ui:
        return
    surface = detect_ui_surface(contract, plan, tests)
    if not surface:
        report.fail(
            f"{spec_dir.name}: has_ui but missing `UI surface: product|consumer|n/a` "
            "(declare in contract.md or plan.md — see design-standards/surfaces/)"
        )
        return
    report.ok(f"{spec_dir.name}: UI surface={surface}")
    if surface == "n/a":
        return
    if not detect_job_brief(contract, plan, tests):
        report.warn(
            f"{spec_dir.name}: has_ui but missing Job Brief "
            "(`Job Brief:` or `Job:` + `Consequence:`/`Desired outcome:` — "
            "see design-standards/product-judgment.md)"
        )
    else:
        report.ok(f"{spec_dir.name}: Job Brief declared")
    if not detect_design_read(contract, plan, tests):
        report.warn(
            f"{spec_dir.name}: has_ui but missing Design Read "
            "(`Reading this as: …` or `Design Read:` — see design-standards/craft-knobs.md)"
        )
    else:
        report.ok(f"{spec_dir.name}: Design Read declared")
    pk = detect_page_kind(contract, plan, tests)
    if not pk:
        report.warn(
            f"{spec_dir.name}: has_ui but no `page_kind:` or `motif:` "
            "(list|detail|settings|dashboard|form|growth|… — see design-standards/LOAD-MAP.md)"
        )
    else:
        report.ok(f"{spec_dir.name}: page_kind/motif={pk}")
    if not detect_anchor(contract, plan, tests):
        report.warn(
            f"{spec_dir.name}: missing usable `anchor:` / `diverge:` "
            "(Build 前须补 — see design-standards/LOAD-MAP.md；not 现代/简洁)"
        )
    else:
        report.ok(f"{spec_dir.name}: anchor declared")
    blob = f"{contract}\n{plan}\n{tests}"
    if surface == "product" and re.search(
        r"新建.*壳|应用壳|sidebar|侧栏布局|AppShell", blob, re.I
    ):
        if not re.search(
            r"shell\s*[:：]\s*`?(floating-card|flush-pane|doc-workspace|data-table|unset)`?",
            blob,
            re.I,
        ):
            report.warn(
                f"{spec_dir.name}: product chrome work suspected but shell not declared "
                "(floating-card|flush-pane|doc-workspace|data-table|unset)"
            )


# Close-gate stamp written by scripts/verify-deliver.sh after exit 0.
VERIFY_DELIVER_STAMP_RE = re.compile(
    r"verify-deliver\s*:\s*ok\s*[·•]\s*\S+",
    re.I,
)
ORACLE_FREEZE_RE = re.compile(r"oracle-freeze\s*:\s*intact\b", re.I)
RED_GREEN_RE = re.compile(
    r"红绿证据\s*[：:]\s*(.+?)(?:\n|$)",
    re.I,
)
RED_GREEN_NA_OK = re.compile(
    r"N/A\s*[·•]\s*(polish|trivial|无自动化)",
    re.I,
)
RED_GREEN_PAIR_OK = re.compile(
    r"(?i)(?:red|红).{0,80}exit\s*=\s*\d+.{0,120}(?:green|绿).{0,80}exit\s*=\s*0",
)


def check_run_honesty(
    spec_dir: Path,
    run: str,
    report: Report,
    *,
    structure_only: bool,
    allow_unstamped_deliver: bool = False,
) -> None:
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
    claims_smoke_pass = bool(
        re.search(r"\[部署[^\]]*prod-smoke\s*通过", run)
        or re.search(r"产品冒烟[^：:\n]*[：:][ \t]*通过\b", run)
    )
    claimed_pass = (
        "acceptance-passed" in status
        or acceptance == "acceptance-passed"
        or deliver == "可交付"
        or claims_smoke_pass
    )
    if claimed_pass and bad:
        report.fail(
            f"{spec_dir.name}/run.md: claims acceptance/可交付 but matrix has "
            f"Fail/Blocked ({len(bad)})"
        )
    elif claimed_pass and not claims_smoke_pass:
        report.ok(f"{spec_dir.name}: run honesty ok (no Fail/Blocked vs acceptance)")

    # Nail 1: close-gate stamp (verify-deliver exit 0 record)
    if claimed_pass and not allow_unstamped_deliver:
        if not VERIFY_DELIVER_STAMP_RE.search(run):
            report.fail(
                f"{spec_dir.name}/run.md: claims 可交付/acceptance-passed/prod-smoke 通过 "
                "but missing `verify-deliver: ok · <time>` "
                "(run `make verify-deliver HOST=<repo> SPEC=<id>` first)"
            )
        else:
            report.ok(f"{spec_dir.name}: verify-deliver stamp present")

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

    # Pass rows must not be smoke-only evidence
    smoke_pass = 0
    for row in matrix:
        if clean(row.get("Test", "")) in EMPTYISH:
            continue
        result = clean(row.get("Result", "")).lower()
        if result != "pass":
            continue
        evidence = ""
        for key, val in row.items():
            if key.lower().startswith("evidence"):
                evidence = val
                break
        if evidence_is_smoke_only(evidence):
            smoke_pass += 1
            report.fail(
                f"{spec_dir.name}/run.md: {clean(row.get('Test', ''))} Pass uses "
                f"smoke/health-only Evidence ({evidence!r}) — need kind=api-diff|"
                "network-har|browser-job (see evidence-contract §1.1)"
            )
    if claimed_pass and smoke_pass:
        report.fail(
            f"{spec_dir.name}/run.md: acceptance/可交付 claimed while {smoke_pass} "
            "Pass row(s) are smoke-only"
        )

    # Deliver claims require Verify rail + falsify trail (not Build-mode chat)
    mode = ""
    m_mode = re.search(r"当前模式：\s*`?([^`|\n]+)`?", run)
    if m_mode:
        mode = clean(m_mode.group(1)).lower()
    if deliver == "可交付":
        if mode and "verify" not in mode and mode not in {"verifying"}:
            report.fail(
                f"{spec_dir.name}/run.md: 是否可以交付=可交付 but 当前模式={mode!r} "
                "(must be verify; Build 轨禁止可交付)"
            )
        if not re.search(r"证伪|falsify", run, re.I):
            report.fail(
                f"{spec_dir.name}/run.md: 可交付 requires 证伪/falsify record "
                "(see testing/falsify-checklist)"
            )
        if "已验证的用户结果" not in run:
            report.fail(
                f"{spec_dir.name}/run.md: 可交付 requires 「已验证的用户结果」 section"
            )

    # Nail 2: Build 宣称实现完成 → oracle-freeze + 红绿证据
    _, batch = parse_md_table_after(run, "批次结果")
    freeze_filled = bool(re.search(r"实现冻结时间[^：:\n]*[：:][ \t]*\S", run))
    batch_has_result = False
    for row in batch:
        for k, v in row.items():
            if k.lower().startswith("结果") or k.lower() == "result":
                if clean(v).lower() in {"pass", "fail", "blocked"}:
                    batch_has_result = True
                break
    claimed_impl = "实现完成" in run or (
        mode in {"build", "building", "repair", "repairing"}
        and freeze_filled
        and batch_has_result
    )
    if claimed_impl and mode in {
        "build",
        "building",
        "repair",
        "repairing",
        "",
    }:
        if not ORACLE_FREEZE_RE.search(run):
            report.fail(
                f"{spec_dir.name}/run.md: Build/Repair claims 实现完成 but missing "
                "`oracle-freeze: intact` (禁改 tests.md / 06-acceptance-matrix; "
                "改 Oracle 须回 Plan + 用户批准)"
            )
        rg = RED_GREEN_RE.search(run)
        if not rg:
            report.fail(
                f"{spec_dir.name}/run.md: Build claims 实现完成 but missing "
                "`红绿证据:` (red…exit=N · green…exit=0 | N/A · polish|trivial|无自动化)"
            )
        else:
            body = clean(rg.group(1))
            if not (RED_GREEN_NA_OK.search(body) or RED_GREEN_PAIR_OK.search(body)):
                report.fail(
                    f"{spec_dir.name}/run.md: 红绿证据 malformed ({body!r}); "
                    "need red+green exit codes or N/A · polish|trivial|无自动化"
                )
            else:
                report.ok(f"{spec_dir.name}: Build oracle-freeze + 红绿证据 ok")

    # Production: P5 filled without P2/P3
    def _prod_field(prefix: str) -> str:
        m = re.search(rf"{prefix}[^：:\n]*[：:][ \t]*([^\n]*)", run)
        return clean(m.group(1)) if m else ""

    def _prod_filled(val: str) -> bool:
        return val not in EMPTYISH and val.lower() not in {
            "—",
            "-",
            "待填",
            "n/a",
            "不适用",
            "tbd",
        }

    p2 = _prod_field(r"P2 发布方案")
    p3 = _prod_field(r"P3 验证方案")
    p5 = _prod_field(r"Deploy\s*/\s*rollback")
    if _prod_filled(p5) and (not _prod_filled(p2) or not _prod_filled(p3)):
        report.fail(
            f"{spec_dir.name}/run.md: Production P5 filled but P2 or P3 empty "
            "(Deploy gate: P2+P3 before P5)"
        )

    # P6 pass requires agent-first probe fields (verification-loop)
    if claims_smoke_pass:
        probe = _prod_field(r"探活执行者")
        evidence = _prod_field(r"产品冒烟证据")
        user_act = _prod_field(r"需要用户做什么")
        probe_ok = probe.lower().replace("_", "-") in {
            "agent",
            "blocked-needs-auth",
        }
        if not _prod_filled(probe) or not probe_ok:
            report.fail(
                f"{spec_dir.name}/run.md: prod-smoke 通过 requires "
                "探活执行者: agent | blocked-needs-auth "
                "(see verification-loop / evidence-contract Deliver Gate)"
            )
        strong = bool(
            re.search(
                r"(?i)kind\s*=\s*(browser-job|api-diff|network-har|integration|unit)",
                evidence,
            )
        )
        weak_only = bool(
            re.search(r"(?i)\bhealth\b|/health|window-smoke|进程\s*active", evidence)
        ) and not strong
        if not _prod_filled(evidence) or weak_only:
            report.fail(
                f"{spec_dir.name}/run.md: prod-smoke 通过 requires "
                "产品冒烟证据 with kind=browser-job|api-diff|network-har|… "
                "(not health/window-smoke alone)"
            )
        if user_act and re.search(
            r"硬刷|打开浏览器|打开页面|确认.*是否|请.*刷新|请.*验收|开无痕",
            user_act,
        ):
            report.fail(
                f"{spec_dir.name}/run.md: prod-smoke 通过 forbids "
                "需要用户做什么 that assigns open/refresh discovery to user "
                f"({user_act!r})"
            )

    # Deliver 可交付: ban user-as-canary next steps
    if deliver == "可交付":
        for m in re.finditer(
            r"需要用户做什么[：:][ \t]*([^\n]+)|下一步[：:][ \t]*([^\n]+)",
            run,
        ):
            act = clean(m.group(1) or m.group(2) or "")
            if re.search(
                r"硬刷|打开浏览器|打开页面|确认.*是否正常|请.*刷新|开无痕",
                act,
            ):
                report.fail(
                    f"{spec_dir.name}/run.md: 可交付 forbids user-as-canary "
                    f"next step ({act!r}); Agent must probe first"
                )

    # Batch table (批次结果) — same rule
    for row in batch:
        result = ""
        evidence = ""
        for key, val in row.items():
            kl = key.lower()
            if kl.startswith("结果") or kl == "result":
                result = clean(val).lower()
            if kl.startswith("证据") or kl.startswith("evidence"):
                evidence = val
        if result == "pass" and evidence_is_smoke_only(evidence):
            report.fail(
                f"{spec_dir.name}/run.md: batch Pass uses smoke-only Evidence "
                f"({clean(evidence)!r})"
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
    *,
    allow_unstamped_deliver: bool = False,
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
    check_tests(
        spec_dir,
        tests,
        req_rows,
        report,
        structure_only=structure_only,
        contract=contract,
        plan=plan,
    )
    has_ui = detect_has_ui(contract, plan, tests)
    check_ui_surface(
        spec_dir,
        contract,
        plan,
        tests,
        has_ui=has_ui,
        report=report,
        structure_only=structure_only,
    )
    check_plan_architecture(
        spec_dir,
        plan,
        has_ui,
        report,
        structure_only=structure_only,
        checklist_dir=checklist_dir,
    )
    check_run_honesty(
        spec_dir,
        run,
        report,
        structure_only=structure_only,
        allow_unstamped_deliver=allow_unstamped_deliver,
    )


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
    parser.add_argument(
        "--allow-unstamped-deliver",
        action="store_true",
        help="Skip verify-deliver stamp check (used by verify-deliver.sh before stamping)",
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
        check_spec_dir(
            d,
            report,
            checklist_dir,
            allow_unstamped_deliver=args.allow_unstamped_deliver,
        )

    print(f"---\nerrors={report.errors} warnings={report.warnings}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
