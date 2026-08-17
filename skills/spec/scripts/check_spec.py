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

# Words the run.md template ships inside cells as "pick one" menus. A cell that
# only restates the menu is an unfilled cell, not evidence.
_OPTION_WORDS = {
    "pass", "fail", "blocked", "agent", "blocked-needs-auth",
    "通过", "未过", "已通过", "未通过", "无法验证", "不适用",
}


def cell_is_placeholder(val: str) -> bool:
    """True for empty cells and for untouched template placeholders."""
    v = clean(val).strip("`").strip()
    if v in EMPTYISH:
        return True
    # `kind=… ·` and friends: nothing left once the label and ellipses go
    body = re.sub(r"(?i)\bkind\s*=", " ", v).replace("…", " ").replace("...", " ")
    if not re.sub(r"[·、,，/|\\\-—:：`\s]+", " ", body).strip():
        return True
    parts = [p.strip(" `").lower() for p in re.split(r"[/|]", v) if p.strip(" `")]
    return len(parts) >= 2 and sum(p in _OPTION_WORDS for p in parts) >= 2


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


def is_table_line(line: str) -> bool:
    """Markdown makes the outer pipes optional, so do we."""
    s = line.strip()
    return "|" in s and not s.startswith("#")


def is_delimiter_row(line: str) -> bool:
    parts = [c.strip() for c in cells(line) if c.strip()]
    return bool(parts) and all(re.fullmatch(r":?-{3,}:?", c) for c in parts)


def has_h3(text: str, name: str) -> bool:
    """### Given, ###  Given and ### Given（Oracle） are the same heading."""
    return bool(re.search(rf"(?m)^\s*#{{2,4}}\s+{re.escape(name)}", text))


def parse_md_table_after(text: str, heading_substr: str) -> tuple[list[str], list[dict[str, str]]]:
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("#") and heading_substr in line:
            start = i + 1
            break
    if start is None:
        return [], []
    while start < len(lines) and not is_table_line(lines[start]):
        if lines[start].startswith("#"):
            return [], []
        start += 1
    if start >= len(lines):
        return [], []
    headers = [clean(h) for h in cells(lines[start])]
    start += 1
    if start < len(lines) and is_delimiter_row(lines[start]):
        start += 1
    rows: list[dict[str, str]] = []
    while start < len(lines) and is_table_line(lines[start]):
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


def detect_has_ui_explicit(contract: str) -> bool:
    return bool(re.search(r"has_ui\s*[:：]\s*true", contract, re.I))


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

# Antipattern Oracles for T-001 / primary success path (scheme-antipatterns.md)
# Class detectors (synonyms), not only surface literals — adversarial rot H1.
LAZY_PATH_ORACLE_RE = re.compile(
    # focus / input takeover
    r"focus\s*(textarea|input|输入框)"
    r"|textarea\s*.{0,12}(焦点|闪烁|光标)"
    r"|光标\s*(落|进|移)"
    r"|插入符"
    r"|输入态\s*高亮"
    r"|获得焦点"
    r"|接管键盘"
    r"|文本编辑区"
    # drawer / sheet / overlay
    r"|打开抽屉|open\s+drawer"
    r"|侧滑|抽屉|drawer"
    r"|right\s*sheet|右侧\s*(浮层|面板|抽屉)"
    r"|浮层.{0,8}(展开|滑入|弹出)"
    r"|面板.{0,8}(展开|弹出|滑入)"
    # CTA click alone
    r"|点击\s*CTA|click\s+(the\s+)?cta"
    # checklist / onboarding tick-complete
    r"|勾完|勾选完成|打钩|划掉|打卡"
    r"|checklist\s*(完成|done|complete)?"
    r"|任务单|任务卡|待办项"
    r"|onboarding.{0,16}(点完|完成|收尾|收官)"
    r"|步骤.{0,8}(点完|打完|走完)"
    r"|教学.{0,12}(收官|收尾|宣告)"
    # lesson / completion rate / badge
    r"|lesson\s*(完成|完成率|complete)"
    r"|完成率\s*[≥>=]?"
    r"|完成度.{0,8}(100|满|％|%)"
    r"|进度条.{0,10}(满|冲到|点亮)"
    r"|徽章\s*点亮"
    # tour / coach / guide
    r"|tour\s*(播完|完成|complete|finished)?"
    r"|导览|coach\s*mark|聚光提示|气泡卡"
    r"|引导\s*(走完|完成|退场|末页)"
    r"|末页.{0,8}(退场|消失|自动)"
    # state-machine / soft-fallback / residual
    r"|状态位|flag\s*(置位|=|true)"
    r"|软回退.*(学会|完成)"
    r"|residual|live[\s_-]?deferred",
    re.IGNORECASE,
)

# Build-done euphemisms (adversarial rot H2) — trigger same honesty as 实现完成
IMPL_DONE_EUPHEMISM_RE = re.compile(
    r"实现完成"
    r"|交卷|收官|封板|落袋"
    r"|Implementation\s+is\s+done"
    r"|implementation\s+complete"
    r"|coding\s+work\s+is\s+wrapped"
    r"|开发(?:工作)?已全部结束"
    r"|改动悉数落地"
    r"|进入交接态"
    r"|施工(?:可)?移交"
    r"|handoff\s+to\s+(?:qa|verification)"
    r"|ready\s+for\s+verification"
    r"|本轮施工",
    re.IGNORECASE,
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
        r"(?m)^\s*#{2,4}\s+Then[^\n]*\n(.*?)(?:\n\s*#{2,4}\s|\Z)",
        test_body,
        re.S,
    )
    return m.group(1) if m else ""


def then_is_lazy_path_oracle(then_text: str) -> bool:
    """True when Then matches scheme-antipatterns lazy observation forms."""
    return bool(LAZY_PATH_ORACLE_RE.search(then_text or ""))


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


RUNNABLE_HEAD = re.compile(
    r"^(?:npx|npm|pnpm|yarn|bun|make|bash|sh|zsh|python3?|pytest|vitest|playwright|"
    r"go|cargo|dotnet|mvn|gradle|docker|curl|psql|\./|/)",
)
NOOP_CMD = re.compile(r"^(?:true|:|exit\s+0|echo|/(?:usr/)?bin/true)\s*;?$")
LEADING_ENV = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=\S*\s+")
# Requirement text that promises something a person can see. A unit test cannot
# close these: sol skipped an entire user-visible requirement and still passed 11/11.
USER_VISIBLE = re.compile(r"(?i)(UI|文案|copy|i18n|locale|双语|翻译|移动端|mobile|响应式|"
                          r"页面|界面|视觉|可读|可访问|aria|截图|screenshot)")
NON_UNIT_ORACLE = re.compile(r"(?i)(playwright|browser|浏览器|e2e|截图|screenshot|"
                             r"i18n|locale|移动端|mobile|\b390|human|人工)")


def automation_command(body: str) -> str | None:
    """The `命令：` / `命令或测试路径：` line inside a test's 自动化 block, if any."""
    block = re.search(
        r"(?ms)^\s*#{2,4}\s+自动化[^\n]*\n(.*?)(?=^\s*#{2,4}\s+|\Z)", body
    )
    if not block:
        return None
    m = re.search(r"(?m)^\s*-\s*命令(?:或测试路径)?\s*[：:]\s*(.+?)\s*$", block.group(1))
    return m.group(1) if m else None


def check_p0_oracle_commands(
    spec_dir: Path,
    tests: str,
    req_rows: list[dict[str, str]],
    report: Report,
    *,
    closing: bool = False,
) -> None:
    """A P0 Oracle must be a command the runner can execute, and must be able to fail.

    Measured holes this closes: check_spec used to accept a P0 test with no command at
    all and one whose command was `true`; and Codex writes referential oracles ("同
    T-001", "S0 确定的 tests") at a rate escalating effort does not fix (3/8 at high vs
    3/6 at medium) — a runner cannot execute those.
    """
    bodies = extract_test_bodies(tests)
    p0: dict[str, str] = {}          # tid -> requirement text that mapped it
    for row in req_rows:
        if clean(row.get("优先级", "")).upper() != "P0":
            continue
        text = " ".join(clean(v) for v in row.values())
        for tid in re.findall(r"T-\d+", clean(row.get("Tests", ""))):
            p0.setdefault(tid, text)
    if not p0:
        return

    visible_reqs: dict[str, list[str]] = {}
    for tid, req_text in sorted(p0.items()):
        body = bodies.get(tid)
        if body is None:
            continue  # the index/body structure check already reports this
        if USER_VISIBLE.search(req_text):
            visible_reqs.setdefault(req_text[:60], []).append(tid)

        cmd = automation_command(body)
        if not cmd:
            report.fail(
                f"{spec_dir.name}/tests.md: P0-mapped {tid} has no 自动化 `命令：` — "
                "the runner has nothing to execute"
            )
            continue
        bare = cmd.strip().strip("`").strip()
        if bare in {"human", "人工"}:
            continue  # human-judged: closes via the acceptance pack, not the runner
        if NOOP_CMD.match(bare):
            report.fail(
                f"{spec_dir.name}/tests.md: P0-mapped {tid} 命令 is a no-op ({bare!r}) — "
                "it stays green with the feature deleted"
            )
            continue
        head = LEADING_ENV.sub("", bare)
        if not RUNNABLE_HEAD.match(head):
            # Measured: 0 of 4 sampled archived Specs and 0 of 14 T-ids in a live Spec
            # would pass this. Blocking Build on it would stop all in-flight work, so it
            # bites where the claim is made instead: you may Build with a referential
            # oracle, you may not close on one.
            (report.fail if closing else report.warn)(
                f"{spec_dir.name}/tests.md: P0-mapped {tid} 命令 is referential, not "
                f"executable ({bare[:60]!r}) — the runner cannot run 「同 T-xxx」/"
                "「S0 确定的…」/「按 xx skill 运行」"
            )

    for req_text, tids in visible_reqs.items():
        pooled = "\n".join(bodies.get(t, "") for t in tids)
        if not NON_UNIT_ORACLE.search(pooled):
            (report.fail if closing else report.warn)(
                f"{spec_dir.name}/tests.md: user-visible requirement ({req_text.strip()[:48]}…) "
                f"is gated only by unit tests via {', '.join(tids)} — needs a browser / i18n / "
                "mobile / human oracle"
            )
    report.ok(f"{spec_dir.name}: P0 oracle commands checked ({len(p0)} ids)")


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
    closing: bool = False,
) -> None:
    if not has_h3(tests, "Given") or not has_h3(tests, "When"):
        report.fail(f"{spec_dir.name}/tests.md: missing Given/When headings")
        return
    if not has_h3(tests, "Then"):
        report.fail(f"{spec_dir.name}/tests.md: missing Then（Oracle）")
        return
    report.ok(f"{spec_dir.name}: tests.md has Given/When/Then markers")
    if structure_only:
        return

    check_p0_oracle_commands(spec_dir, tests, req_rows, report, closing=closing)

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
        for need in ("Given", "When"):
            if not has_h3(body, need):
                report.fail(f"{spec_dir.name}/tests.md: {tid} missing ### {need}")
        if not has_h3(body, "Then"):
            report.fail(f"{spec_dir.name}/tests.md: {tid} missing ### Then")
        # empty placeholders: Given section should have more than labels only
        given = re.search(r"(?m)^\s*#{2,4}\s+Given[^\n]*\n(.*?)(?:\n\s*#{2,4}\s|\Z)", body, re.S)
        if given and not re.search(r"[^\s\-：:].{3,}", given.group(1)):
            report.warn(f"{spec_dir.name}/tests.md: {tid} Given looks empty")
        then = extract_then_body(body)
        if then and then_is_weak(then):
            report.warn(
                f"{spec_dir.name}/tests.md: {tid} Then carries no distinguishing "
                "assertion (empty, or only '能打开/有数据/冒烟通过' — see oracle-strength.md)"
            )
        # T-001 (or first success) must not use antipattern observation forms
        if then and then_is_lazy_path_oracle(then):
            is_primary = tid == "T-001" or (
                "success" in clean(
                    next(
                        (
                            r.get("Type", "")
                            for r in index_rows
                            if clean(r.get("ID", "")) == tid
                        ),
                        "",
                    )
                ).lower()
                and tid == sorted(index_ids)[0]
            )
            if is_primary or tid == "T-001":
                report.warn(
                    f"{spec_dir.name}/tests.md: {tid} Then hits scheme-antipatterns "
                    "(checklist/tour/focus/drawer/completion-rate class — "
                    "see design/references/scheme-antipatterns.md)"
                )

    # Data-surface: at least one Then must carry falsify hints
    if detect_data_surface(contract, plan, tests):
        all_thens = "\n".join(extract_then_body(b) for b in bodies.values())
        if not FALSIFY_HINT_RE.search(all_thens):
            report.warn(
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
        msg = (
            f"{spec_dir.name}: has_ui but missing `UI surface: product|consumer|n/a` "
            "(declare in contract.md or plan.md — see design-standards/LOAD-MAP.md)"
        )
        if detect_has_ui_explicit(contract):
            report.fail(msg)
        else:
            report.warn(msg + " (heuristic has_ui only)")
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
# P3: Build 实现完成 must cite dispatch jsonl OR explicit self-write override
DISPATCH_PATH_RE = re.compile(
    r"\.codex-dispatch-logs/([^\s`]+?\.jsonl)",
    re.I,
)
DISPATCH_RUN_ID_RE = re.compile(
    r"dispatch[_-]?(?:run[_-]?)?id\s*[:=]\s*[`\"]?([^\s`\"\n]+)",
    re.I,
)
# Bare `override: polish` is forgeable (H3). Require user-explicit phrasing.
OVERRIDE_SELF_RE = re.compile(
    r"override\s*:\s*(?:"
    r"用户要求自写"
    r"|不用\s*Codex"
    r"|你自己写"
    r"|(?:用户(?:要求|明示)|本轮明示).{0,40}(?:polish|trivial|自写)"
    r"|polish\s*[·•].{0,60}(?:用户|明示)"
    r"|trivial\s*[·•].{0,60}(?:用户|明示)"
    r")",
    re.I,
)
_FIXTURE_SPEC_NAMES = frozenset(
    {
        "demo",
        "atk",
        "pure",
        "lazy",
        "lazy-oracle",
        "_template",
    }
)


def _dispatch_log_dirs(start: Path | None = None) -> list[Path]:
    dirs: list[Path] = []
    seen: set[Path] = set()
    candidates = [Path.cwd()]
    if start is not None:
        candidates.append(start.resolve())
        candidates.extend(start.resolve().parents)
    for base in candidates:
        d = (base / ".codex-dispatch-logs").resolve()
        if d.is_dir() and d not in seen:
            seen.add(d)
            dirs.append(d)
        # host root often has logs; stop after a few parents
        if len(dirs) >= 4:
            break
    return dirs


def _resolve_dispatch_jsonl(run_id_or_name: str, start: Path | None = None) -> Path | None:
    name = run_id_or_name.strip().strip("`\"'")
    if not name:
        return None
    if not name.endswith(".jsonl"):
        name_jsonl = f"{name}.jsonl"
    else:
        name_jsonl = name
    base = Path(name_jsonl).name
    stem = base[: -len(".jsonl")] if base.endswith(".jsonl") else base
    for log_dir in _dispatch_log_dirs(start):
        direct = log_dir / base
        if direct.is_file():
            return direct
        # allow prefix match: goal_*_{pid}.jsonl cited as run-id
        for p in sorted(log_dir.glob("*.jsonl")):
            if stem and stem in p.name:
                return p
    # absolute / cwd-relative path citation
    cand = Path(name)
    if cand.is_file() and cand.suffix == ".jsonl":
        return cand.resolve()
    cwd_cand = Path.cwd() / name
    if cwd_cand.is_file():
        return cwd_cand.resolve()
    return None


def dispatch_evidence_valid(
    run: str,
    spec_dir: Path,
    *,
    allow_override: bool = True,
) -> tuple[bool, str]:
    """Return (ok, reason). Prefer dispatch-run-id → existing completed jsonl.

    All cited run-ids must be valid. Spec id match uses token boundaries
    (good-spec must not match inside good-spec-v2).
    """
    if allow_override and OVERRIDE_SELF_RE.search(run):
        return True, "override"

    run_ids = [m.group(1) for m in DISPATCH_RUN_ID_RE.finditer(run)]
    if not run_ids:
        if DISPATCH_PATH_RE.search(run):
            return False, (
                "path-only .codex-dispatch-logs/*.jsonl rejected — "
                "add `dispatch-run-id: <id>` matching an existing completed jsonl"
            )
        return False, "missing dispatch-run-id: <id> or override: …"

    validated: list[str] = []
    for token in run_ids:
        path = _resolve_dispatch_jsonl(token, spec_dir)
        if path is None or not path.is_file():
            return False, f"dispatch jsonl missing for {token!r}"
        try:
            body = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return False, f"cannot read {path.name}"
        if path.stat().st_size < 80:
            return False, f"{path.name} too small to be a completed run"
        if not re.search(r"turn\.completed|\"type\"\s*:\s*\"turn\.completed\"", body):
            return False, f"{path.name} missing turn.completed"
        spec_name = spec_dir.name
        if (
            spec_name
            and spec_name not in _FIXTURE_SPEC_NAMES
            and len(spec_name) >= 3
        ):
            bound = re.search(
                rf"(?<![A-Za-z0-9_-]){re.escape(spec_name)}(?![A-Za-z0-9_-])",
                body,
            ) or (
                f"--spec {spec_name}" in body or f"--spec={spec_name}" in body
            )
            if not bound:
                return False, (
                    f"{path.name} does not mention spec id {spec_name!r} "
                    "(refuse unrelated jsonl reuse)"
                )
        validated.append(path.name)
    return True, ",".join(validated)


def _matrix_evidence(row: dict) -> str:
    for key, val in row.items():
        kl = key.lower()
        if kl.startswith("evidence") or kl.startswith("证据"):
            return val
    return clean(row.get("Evidence", ""))


EVIDENCE_PATH_RE = re.compile(r"(?i)\b(?:log|path|file|artifact|report)\s*=\s*([^\s·,，、|]+)")


def _resolve_cited(p: str, spec_dir: Path) -> Path | None:
    cand = Path(p)
    if cand.is_absolute():
        return cand if cand.exists() else None
    roots = [spec_dir, *spec_dir.parents[:3]]
    return next((r / p for r in roots if (r / p).exists()), None)


def evidence_paths(cell: str, spec_dir: Path) -> list[tuple[str, Path | None]]:
    """(cited path, resolved path or None) for paths an Evidence cell names.

    Only `log=`/`path=`/`file=`… are read: this verifies claims the author
    already made rather than demanding a new artifact.
    """
    out = []
    for raw in EVIDENCE_PATH_RE.findall(cell):
        p = raw.strip("`'\"()")
        if not p or p.startswith(("http://", "https://")) or "…" in p or "*" in p:
            continue
        out.append((p, _resolve_cited(p, spec_dir)))
    return out


def missing_evidence_paths(cell: str, spec_dir: Path) -> list[str]:
    return [p for p, hit in evidence_paths(cell, spec_dir) if hit is None]


def closing_anchor(run: str, spec_dir: Path, evidence_cells: list[str]) -> str:
    """Something on disk that closing rests on, so typing alone cannot close."""
    for cell in evidence_cells:
        for p, hit in evidence_paths(cell, spec_dir):
            if hit is not None:
                return f"evidence path {p}"
    ok, _ = dispatch_evidence_valid(run, spec_dir, allow_override=False)
    if ok:
        return "dispatch jsonl"
    for m in re.finditer(r"[\w./\\-]*_falsify\.log", run):
        if _resolve_cited(m.group(0).strip("`"), spec_dir):
            return f"falsify log {m.group(0)}"
    return ""


def check_run_honesty(
    spec_dir: Path,
    run: str,
    report: Report,
    *,
    structure_only: bool,
    closing: bool = False,
) -> None:
    if structure_only or not run:
        return

    smoke_field = re.search(r"产品冒烟[^：:\n]*[：:][ \t]*([^\n]*)", run)
    claims_smoke = bool(re.search(r"\[部署[^\]]*prod-smoke\s*通过", run)) or bool(
        smoke_field
        and re.match(r"通过\b", clean(smoke_field.group(1)))
        and not cell_is_placeholder(smoke_field.group(1))
    )
    _, matrix = parse_md_table_after(run, "追踪矩阵")
    _, batch = parse_md_table_after(run, "批次结果")

    def _prod_field(prefix: str) -> str:
        m = re.search(rf"{prefix}[^：:\n]*[：:][ \t]*([^\n]*)", run)
        return clean(m.group(1)) if m else ""

    def _prod_filled(val: str) -> bool:
        return val not in EMPTYISH and val.lower() not in {
            "—", "-", "待填", "n/a", "不适用", "tbd",
        }

    if closing:
        bad = sum(
            1
            for r in matrix
            if clean(r.get("Test", "")) not in EMPTYISH
            and clean(r.get("Result", "")).lower() in {"fail", "blocked"}
        )
        if bad:
            report.fail(
                f"{spec_dir.name}/run.md: closing but matrix has Fail/Blocked ({bad})"
            )
        passing = [
            r
            for r in matrix
            if not cell_is_placeholder(r.get("Test", ""))
            and clean(r.get("Result", "")).lower() == "pass"
        ]
        if not passing:
            report.fail(
                f"{spec_dir.name}/run.md: closing requires at least one 追踪矩阵 row "
                "with a real Test and Result=Pass"
            )
        evidence_cells = [clean(_matrix_evidence(r)) for r in passing]
        if not evidence_cells or all(cell_is_placeholder(e) for e in evidence_cells):
            report.fail(
                f"{spec_dir.name}/run.md: closing requires non-empty Evidence column"
            )
        for cell in evidence_cells:
            for missing in missing_evidence_paths(cell, spec_dir):
                report.fail(
                    f"{spec_dir.name}/run.md: Evidence names a path that does not "
                    f"exist ({missing})"
                )
        if not closing_anchor(run, spec_dir, evidence_cells):
            report.fail(
                f"{spec_dir.name}/run.md: closing requires one artifact on disk — "
                "an Evidence `log=`/`path=` that exists, a dispatch-run-id with a "
                "completed jsonl, or the falsify PASS log"
            )
        ok_ev, ev_reason = dispatch_evidence_valid(run, spec_dir)
        if not ok_ev:
            report.fail(
                f"{spec_dir.name}/run.md: closing requires dispatch evidence ({ev_reason})"
            )
        has_kind = any(
            re.search(r"(?i)kind\s*=", e)
            for e in evidence_cells
            if not cell_is_placeholder(e)
        )
        if not re.search(r"证伪|falsify", run, re.I) and not has_kind:
            report.fail(
                f"{spec_dir.name}/run.md: closing requires falsify mention or "
                "Evidence with kind="
            )

    for row in matrix:
        if clean(row.get("Test", "")) in EMPTYISH:
            continue
        if clean(row.get("Result", "")).lower() != "pass":
            continue
        ev = clean(_matrix_evidence(row))
        if evidence_is_smoke_only(ev):
            report.fail(
                f"{spec_dir.name}/run.md: {clean(row.get('Test', ''))} Pass uses "
                f"smoke-only Evidence ({ev!r})"
            )

    p2, p3, p5 = (
        _prod_field(r"P2 发布方案"),
        _prod_field(r"P3 验证方案"),
        _prod_field(r"Deploy\s*/\s*rollback"),
    )
    if _prod_filled(p5) and (not _prod_filled(p2) or not _prod_filled(p3)):
        report.fail(f"{spec_dir.name}/run.md: Production P5 filled but P2 or P3 empty")

    if claims_smoke:
        probe, evid, user_act = (
            _prod_field(r"探活执行者"),
            _prod_field(r"产品冒烟证据"),
            _prod_field(r"需要用户做什么"),
        )
        if probe.lower().replace("_", "-") not in {"agent", "blocked-needs-auth"}:
            report.fail(
                f"{spec_dir.name}/run.md: prod-smoke 通过 requires "
                "探活执行者: agent | blocked-needs-auth"
            )
        strong = bool(
            re.search(
                r"(?i)kind\s*=\s*(browser-job|api-diff|network-har|integration|unit)",
                evid,
            )
        )
        if not _prod_filled(evid) or (
            re.search(r"(?i)\bhealth\b|/health|window-smoke", evid) and not strong
        ):
            report.fail(
                f"{spec_dir.name}/run.md: prod-smoke 通过 requires "
                "产品冒烟证据 with kind=browser-job|api-diff|…"
            )
        if user_act and re.search(r"硬刷|打开浏览器|打开页面|请.*刷新|开无痕", user_act):
            report.fail(
                f"{spec_dir.name}/run.md: prod-smoke 通过 forbids user-as-canary ({user_act!r})"
            )

    for row in batch:
        res, evid = "", ""
        for k, v in row.items():
            kl = k.lower()
            if kl.startswith("结果") or kl == "result":
                res = clean(v).lower()
            if kl.startswith("证据") or kl.startswith("evidence"):
                evid = v
        if res == "pass" and evidence_is_smoke_only(evid):
            report.fail(
                f"{spec_dir.name}/run.md: batch Pass uses smoke-only Evidence "
                f"({clean(evid)!r})"
            )

    freeze = bool(re.search(r"实现冻结时间[^：:\n]*[：:][ \t]*\S", run))
    batch_ok = any(
        clean(v).lower() in {"pass", "fail", "blocked"}
        for row in batch
        for k, v in row.items()
        if k.lower().startswith("结果") or k.lower() == "result"
    )
    if IMPL_DONE_EUPHEMISM_RE.search(run) or (freeze and batch_ok):
        if not ORACLE_FREEZE_RE.search(run):
            report.fail(
                f"{spec_dir.name}/run.md: claims implementation done but missing "
                "`oracle-freeze: intact`"
            )
        rg = RED_GREEN_RE.search(run)
        if not rg:
            report.fail(
                f"{spec_dir.name}/run.md: claims implementation done but missing `红绿证据:`"
            )
        elif not (
            RED_GREEN_NA_OK.search(clean(rg.group(1)))
            or RED_GREEN_PAIR_OK.search(clean(rg.group(1)))
        ):
            report.fail(f"{spec_dir.name}/run.md: 红绿证据 malformed ({clean(rg.group(1))!r})")
        ok_ev, ev_reason = dispatch_evidence_valid(run, spec_dir)
        if not ok_ev:
            report.fail(
                f"{spec_dir.name}/run.md: claims implementation done but dispatch "
                f"evidence invalid ({ev_reason})"
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


SKIP_SPEC_DIR_NAMES = {"_template", "archive"}


def resolve_spec_dir(specs_root: Path, spec_arg: str) -> Path:
    """Resolve id or path; prefer active specs/<id>, then specs/archive/<id>."""
    p = Path(spec_arg)
    if p.is_absolute():
        return p.resolve()
    cand = specs_root / spec_arg
    if cand.is_dir() and spec_arg not in SKIP_SPEC_DIR_NAMES:
        return cand.resolve()
    archived = specs_root / "archive" / Path(spec_arg).name
    if archived.is_dir():
        return archived.resolve()
    cwd_cand = Path.cwd() / spec_arg
    if cwd_cand.is_dir():
        return cwd_cand.resolve()
    return p.resolve()


def find_spec_dirs(docs: Path, spec_arg: str | None, all_specs: bool) -> list[Path]:
    specs_root = docs / "specs"
    if spec_arg:
        return [resolve_spec_dir(specs_root, spec_arg)]
    if not specs_root.is_dir():
        return []
    dirs = sorted(
        d
        for d in specs_root.iterdir()
        if d.is_dir()
        and not d.name.startswith(".")
        and d.name not in SKIP_SPEC_DIR_NAMES
    )
    if all_specs:
        return dirs
    # default: active (non-template, non-archive); if none, check template structure-only
    if dirs:
        return dirs
    tmpl = specs_root / "_template"
    return [tmpl] if tmpl.is_dir() else []


def check_spec_dir(
    spec_dir: Path,
    report: Report,
    checklist_dir: Path,
    *,
    closing: bool = False,
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
        closing=closing,
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
        closing=closing,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="SDD Spec static + honesty gates")
    parser.add_argument("host", help="Host repo root")
    parser.add_argument(
        "spec",
        nargs="?",
        help="Spec id under <SDD root>/specs/ or specs/archive/, or path to Spec dir",
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
        "--closing",
        action="store_true",
        help="Close-gate mode: require Evidence + dispatch/override + falsify (make verify-deliver)",
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
            closing=args.closing,
        )

    print(f"---\nerrors={report.errors} warnings={report.warnings}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
