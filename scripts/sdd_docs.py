#!/usr/bin/env python3
"""sdd_docs.py — SDD docs tree: check (C1..C10), gen (generated sections), mv (move + relink).

Usage:
  sdd_docs.py check <host> [--files F ...] [--today YYYY-MM-DD]
  sdd_docs.py gen   <host> [--check]
  sdd_docs.py mv    <host> OLD NEW [OLD NEW ...]

Host bindings are read from <host>/AGENTS.md lines of the form `- SDD <key>: <value>`:
  docs root · archive dir · gap register · gap dir · legacy paths · size exempt · strict since
Standard library only.
"""
from __future__ import annotations

import datetime as dt
import fnmatch
import os
import re
import subprocess
import sys
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
WORK = ("open", "shaping", "ready", "planned", "done", "parked", "dropped", "merged")
WORK_LIVE = ("open", "shaping", "ready", "planned")
SPEC = ("draft", "ready", "in-progress", "verifying", "blocked", "archived", "cancelled")
VERSION_STATES = ("draft", "active", "archived", "cancelled")
DEFAULT_LEGACY = ("docs/specs/<id>", "reference/handoff.md", "reference/claims.md", "planning/roadmap.md")
BUDGET_AGENTS = 24 * 1024
BUDGET_EVERGREEN = 40 * 1024
BUDGET_HANDOFF = 15 * 1024
BUDGET_HUB = 12 * 1024
HANDOFF_KEEP = 10
VERSION_MAX_DAYS = 42
LINK = re.compile(r"\]\((?:<(?P<ap>[^>#]+)>|(?P<p>[^)\s#<>]+))(?P<anc>#[^)\s>]*)?>?(?:\s+\"[^\"]*\")?\)")
REFDEF = re.compile(r"(?m)^ {0,3}\[[^\]\n]+\]:[ \t]*<?(?P<p>[^\s>#]+)>?(?P<anc>#\S*)?")
MARKER = re.compile(r"<!--\s*/?\s*sdd:gen\b[^>]*-->")
GOOD_MARKER = re.compile(r"<!-- (/?)sdd:gen ([\w-]+) -->")
TEXT_EXTS = (".md", ".mdc", ".yaml", ".yml", ".py", ".sh", ".ts", ".tsx", ".mjs", ".js", ".json", ".toml",
             ".txt", ".ini", ".cfg", ".sql")
TEXT_NAMES = ("Makefile", "Dockerfile", ".gitignore")
TYPE_OF = {"iterations": "iteration", "operations/requests": "request", "operations/incidents": "incident",
           "reports": "report"}
GEN = re.compile(r"(<!-- sdd:gen (?P<name>[\w-]+) -->\n)(?P<body>.*?)(<!-- /sdd:gen (?P=name) -->)", re.S)


# ----------------------------------------------------------------------------- config
class Host:
    def __init__(self, root: Path):
        self.root = root.resolve()
        agents = self.root / "AGENTS.md"
        text = agents.read_text(encoding="utf-8") if agents.is_file() else ""
        b = {}
        for m in re.finditer(r"^\s*-\s*SDD ([a-z ]+):\s*(.+?)\s*$", text, re.M):
            b[m.group(1).strip()] = m.group(2).strip().strip("`")
        self.b = b
        self.docs_rel = b.get("docs root", "docs").rstrip("/")
        self.docs = self.root / self.docs_rel
        self.archive = self.docs / b.get("archive dir", "_archive")
        self.gap_register = self.root / b["gap register"] if "gap register" in b else self.docs / "product/gap-register.md"
        self.gap_dir = self.root / b["gap dir"] if "gap dir" in b else self.docs / "product/gaps"
        self.legacy = list(DEFAULT_LEGACY) + [x.strip().strip("`") for x in b.get("legacy paths", "").split(",") if x.strip()]
        self.size_exempt = [x.strip().strip("`") for x in b.get("size exempt", "").split(",") if x.strip()]
        self.strict_since = b.get("strict since", "")

    def rel(self, p: Path) -> str:
        return p.resolve().relative_to(self.root).as_posix()


# ----------------------------------------------------------------------------- helpers
_ORIG: dict[Path, str] = {}


def read(p: Path) -> str:
    """Read keeping line endings as-is (CRLF survives a rewrite)."""
    with open(p, encoding="utf-8", errors="replace", newline="") as f:
        t = f.read()
    _ORIG.setdefault(p.resolve(), t)
    return t


def write(p: Path, text: str) -> None:
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def link_path(m) -> str:
    return m.group("ap") if m.group("ap") is not None else m.group("p")


def fmt_link(path: str, anc: str, angle: bool) -> str:
    return "](<%s%s>)" % (path, anc) if angle or " " in path else "](%s%s)" % (path, anc)


def link_targets(text: str):
    """(path, anchor) for inline and reference-style links outside code (fenced or inline)."""
    body = strip_code(text)
    for m in LINK.finditer(body):
        yield link_path(m), (m.group("anc") or "")
    for m in REFDEF.finditer(body):
        yield m.group("p"), (m.group("anc") or "")


def front_matter(text: str) -> tuple[dict, int]:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}, 0
    d = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^([\w-]+):\s*(.*)$", line)
        if mm:
            d[mm.group(1)] = mm.group(2).strip().strip('"').strip("'")
    return d, m.end()


def set_front(text: str, key: str, value: str) -> str:
    fm, end = front_matter(text)
    if not end:
        return text
    block = text[4:end - 5]
    if re.search(rf"^{key}:", block, re.M):
        block = re.sub(rf"^{key}:.*$", f"{key}: {value}", block, count=1, flags=re.M)
    else:
        block += f"\n{key}: {value}"
    return "---\n" + block + "\n---\n" + text[end:]


def first_heading(text: str) -> str:
    m = re.search(r"^#\s+(.+)$", text, re.M)
    return m.group(1).strip() if m else ""


def git(host: Host, *args: str) -> str:
    """Git runs in SDD_GIT_ROOT when set: lets `check` read an exported index while history comes from the repo."""
    root = os.environ.get("SDD_GIT_ROOT") or str(host.root)
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True).stdout


_ADDED: dict[str, dict[str, str]] = {}


def added_map(host: Host) -> dict[str, str]:
    """repo-relative path -> date it first entered git, carried across renames (one git call)."""
    key = str(host.root)
    if key in _ADDED:
        return _ADDED[key]
    out = git(host, "log", "--reverse", "-M", "--name-status", "--format=@%cs", "--", host.docs_rel, "AGENTS.md")
    m: dict[str, str] = {}
    date = ""
    for line in out.splitlines():
        if line.startswith("@"):
            date = line[1:]; continue
        parts = line.split("\t")
        if not parts or not parts[0]:
            continue
        st = parts[0]
        if st.startswith("A") and len(parts) >= 2:
            m.setdefault(parts[1], date)
        elif st.startswith("D") and len(parts) >= 2:
            m.pop(parts[1], None)
        elif st.startswith("R") and len(parts) >= 3:
            m[parts[2]] = m.get(parts[1], date)
    # staged renames keep the age of their source
    staged = git(host, "diff", "--cached", "-M", "--name-status").splitlines()
    for line in staged:
        parts = line.split("\t")
        if parts and parts[0].startswith("R") and len(parts) >= 3 and parts[1] in m:
            m[parts[2]] = m[parts[1]]
    _ADDED[key] = m
    return m


def added_date(host: Host, p: Path) -> str | None:
    return added_map(host).get(host.rel(p))


def strip_code(text: str) -> str:
    text = re.sub(r"(?ms)^ {0,3}(```|~~~).*?^ {0,3}\1[^\n]*$", "", text)
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    return re.sub(r"(`+)(?!`).+?(?<!`)\1(?!`)", "``", text)


def is_external(t: str) -> bool:
    return re.match(r"^([A-Za-z][A-Za-z0-9+.-]*:|#|/|~)", t) is not None


def md_files(base: Path):
    for p in sorted(base.rglob("*.md")):
        if "node_modules" in p.parts:
            continue
        yield p


_ANCHORS: dict[Path, set[str]] = {}


def gh_slug(h: str) -> str:
    """GitHub heading anchor: lowercase, drop punctuation except - and _, spaces to -."""
    h = re.sub(r"<[^>]+>", "", h).strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def anchors_of(p: Path) -> set[str]:
    p = p.resolve()
    if p not in _ANCHORS:
        t = re.sub(r"```.*?```", "", read(p), flags=re.S)
        out, seen = set(), {}
        for h in re.findall(r"(?m)^#{1,6}\s+(.+?)\s*#*\s*$", t):
            a = gh_slug(h); n = seen.get(a, 0)
            out.add(a if n == 0 else f"{a}-{n}"); seen[a] = n + 1
        out |= set(re.findall(r'<a\s+(?:id|name)="([^"]+)"', t))
        _ANCHORS[p] = out
    return _ANCHORS[p]


def anchor_ok(target: Path, anchor: str) -> bool:
    from urllib.parse import unquote
    a = unquote(anchor).lower()
    if not a or re.fullmatch(r"l\d+(-l\d+)?", a):   # GitHub line anchors
        return True
    return a in anchors_of(target)


def spec_status(version_md: Path) -> str | None:
    t = read(version_md)
    m = re.search(r"^\|\s*\**状态\**\s*\|\s*`?([a-z-]+)", t, re.M) or re.search(r"^-\s*Status:\s*`?([a-z-]+)", t, re.M)
    return m.group(1) if m else None


def versions(host: Host) -> list[Path]:
    it = host.docs / "iterations"
    if not it.is_dir():
        return []
    return sorted(p.parent for p in it.glob("*/*/*/README.md")
                  if not any(x.startswith("_") for x in p.relative_to(it).parts))


def derived_version_status(vdir: Path) -> str:
    sts = [spec_status(v) for v in sorted(vdir.glob("*/VERSION.md"))]
    sts = [s for s in sts if s]
    if not sts:
        # a version with no Spec may be closed by hand (merged elsewhere, never started)
        fm, _ = front_matter(read(vdir / "README.md")) if (vdir / "README.md").is_file() else ({}, 0)
        return fm.get("status") if fm.get("status") in ("cancelled", "archived") else "draft"
    if all(s in ("archived", "cancelled") for s in sts):
        return "cancelled" if all(s == "cancelled" for s in sts) else "archived"
    if any(s != "draft" for s in sts):
        return "active"
    return "draft"


# ----------------------------------------------------------------------------- demand pool
DEM_COLS = ("ID", "日期", "类型", "用户问题 / 目标", "优先级建议", "状态", "复审日", "说明", "真源 / 版本 / 报告")


def demand_rows(host: Host):
    p = host.docs / "product/demand-pool.md"
    if not p.is_file():
        return p, None, []
    text = read(p)
    m = re.search(r"^## 条目\s*$", text, re.M)
    if not m:
        return p, None, []
    lines = text[m.end():].splitlines()
    header = None
    rows = []
    for i, line in enumerate(lines):
        if not line.startswith("|"):
            if header is not None and rows:
                break
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = cells
            continue
        if set(line.replace("|", "").strip()) <= set("-: "):
            continue
        rows.append(dict(zip(header, cells)))
    return p, header, rows


def strip_md(s: str) -> str:
    return re.sub(r"[`*]", "", s).strip()


# ----------------------------------------------------------------------------- gaps
def gap_files(host: Host) -> list[Path]:
    if not host.gap_dir or not host.gap_dir.is_dir():
        return []
    return sorted(host.gap_dir.glob("GAP-*.md"))


SEV_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}


# ----------------------------------------------------------------------------- generators
def gen_iterations(host: Host) -> str:
    rows = ["| 版本 | 状态 | 目标 |", "|---|---|---|"]
    for v in versions(host):
        fm, _ = front_matter(read(v / "README.md"))
        rel = v.relative_to(host.docs / "iterations").as_posix()
        title = fm.get("title") or first_heading(read(v / "README.md"))
        rows.append(f"| [{rel}](./{rel}/README.md) | `{derived_version_status(v)}` | {title} |")
    return "\n".join(rows) + "\n"


def report_entries(host: Host):
    base = host.docs / "reports"
    out = []
    if not base.is_dir():
        return out
    for p in sorted(base.iterdir()):
        if p.name.startswith(("_", ".")) or p.name == "README.md":
            continue
        if p.is_file() and p.suffix == ".md":
            out.append((p.name, p, p))
        elif p.is_dir():
            mds = sorted(p.glob("*.md"))
            if not mds:
                continue
            entry = p / "README.md" if (p / "README.md").is_file() else mds[0]
            out.append((p.name + "/", p, entry))
    return out


def gen_reports(host: Host) -> str:
    groups: dict[str, list[str]] = {}
    for name, p, entry in report_entries(host):
        t = read(entry)
        fm, _ = front_matter(t)
        topic = fm.get("topic") or "未分类"
        title = fm.get("title") or first_heading(t) or name
        link = entry.relative_to(host.docs / "reports").as_posix()
        sup = f"（已被 {fm['superseded-by']} 取代）" if fm.get("superseded-by") else ""
        groups.setdefault(topic, []).append(f"- [{name.rstrip('/')}](./{link})：{title}{sup}")
    out = []
    for topic in sorted(groups, key=lambda x: (x == "未分类", x)):
        out.append(f"### {topic}\n")
        out += sorted(groups[topic], reverse=True)
        out.append("")
    return "\n".join(out)


def incident_entries(host: Host):
    base = host.docs / "operations/incidents"
    out = []
    if not base.is_dir():
        return out
    for p in sorted(base.iterdir(), reverse=True):
        if p.name.startswith(("_", ".")) or p.name == "README.md":
            continue
        if p.is_file() and p.suffix == ".md":
            out.append((p.name, p))
        elif p.is_dir() and (p / "README.md").is_file():
            out.append((p.name + "/", p / "README.md"))
    return out


def gen_incidents(host: Host) -> str:
    rows = ["| 记录 | 状态 | 说明 |", "|---|---|---|"]
    for name, entry in incident_entries(host):
        t = read(entry)
        fm, _ = front_matter(t)
        link = entry.relative_to(host.docs / "operations/incidents").as_posix()
        rows.append(f"| [{name.rstrip('/')}](./{link}) | `{fm.get('status', '—')}` | {fm.get('title') or first_heading(t)} |")
    return "\n".join(rows) + "\n"


def gen_gaps(host: Host) -> str:
    items = []
    for p in gap_files(host):
        fm, _ = front_matter(read(p))
        items.append((fm, p))
    reg_dir = host.gap_register.parent
    def row(fm, p):
        link = os.path.relpath(p, reg_dir).replace(os.sep, "/")
        return (f"| [{fm.get('id', p.stem)}]({link}) | {fm.get('title', '')} | {fm.get('severity', '')} | "
                f"`{fm.get('status', '')}` | {fm.get('owner', '')} | {fm.get('review', '')} |")
    head = ["| ID | 标题 | 严重度 | 状态 | 负责人 | 复审日 |", "|---|---|---|---|---|---|"]
    live = [x for x in items if x[0].get("status") in WORK_LIVE]
    live.sort(key=lambda x: (SEV_ORDER.get(x[0].get("severity", ""), 9), x[0].get("id", "")))
    parked = sorted([x for x in items if x[0].get("status") == "parked"], key=lambda x: x[0].get("id", ""))
    ended = sorted([x for x in items if x[0].get("status") in ("done", "dropped", "merged")], key=lambda x: x[0].get("id", ""))
    out = [f"### 在办（{len(live)}）\n"] + head + [row(*x) for x in live]
    out += ["", f"### 暂缓（{len(parked)}）\n"] + head + [row(*x) for x in parked]
    out += ["", f"### 已结束（{len(ended)}）\n"] + head + [row(*x) for x in ended]
    return "\n".join(out) + "\n"


def gen_handoff_active(host: Host) -> str:
    rows = ["| 在途版本 | 状态 | 目标 |", "|---|---|---|"]
    for v in versions(host):
        st = derived_version_status(v)
        if st != "active":
            continue
        fm, _ = front_matter(read(v / "README.md"))
        link = os.path.relpath(v / "README.md", host.docs).replace(os.sep, "/")
        rows.append(f"| [{v.name}]({link}) | `{st}` | {fm.get('title') or first_heading(read(v / 'README.md'))} |")
    return "\n".join(rows) + "\n"


def relink_text(text: str, old_dir: Path, new_dir: Path) -> str:
    def f(m):
        t = link_path(m)
        if is_external(t):
            return m.group(0)
        tgt = os.path.normpath(os.path.join(old_dir, t))
        return fmt_link(os.path.relpath(tgt, new_dir).replace(os.sep, "/"), m.group("anc") or "", m.group("ap") is not None)
    return LINK.sub(f, text)


def rotate_handoff(host: Host, text: str) -> tuple[str, dict[Path, str]]:
    """Keep the newest HANDOFF_KEEP dated `## YYYY-MM-DD` sections under budget; archive the oldest.

    Age is the section date, not its position, so newest-first and append-only files both work; for
    equal dates the file's own order decides. Undated `## ` sections (standing notes) never move."""
    parts = re.split(r"(?m)^(?=## )", text)
    head, secs = parts[0], parts[1:]
    dated = [i for i, x in enumerate(secs) if re.match(r"## \d{4}-\d{2}-\d{2}", x)]
    if not dated:
        return text, {}
    first, last = secs[dated[0]][3:13], secs[dated[-1]][3:13]
    newest_first = first >= last
    def age_key(i):  # smaller = older
        return (secs[i][3:13], -i if newest_first else i)
    moved_idx: set[int] = set()
    def size():
        return len((head + "".join(x for k, x in enumerate(secs) if k not in moved_idx)).encode())
    live = sorted(dated, key=age_key)
    while live and (len(live) > HANDOFF_KEEP or (size() > BUDGET_HANDOFF and len(live) > 3)):
        moved_idx.add(live.pop(0))
    if not moved_idx:
        return text, {}
    arch: dict[Path, str] = {}
    for i in sorted(moved_idx, key=age_key):
        s_ = secs[i]
        ap = host.archive / "handoff" / f"handoff-archive-{s_[3:10]}.md"
        body = relink_text(s_, host.docs, ap.parent)
        body = re.sub(r"(?m)^## ", "### ", body, count=1)
        arch[ap] = arch.get(ap, "") + body.rstrip("\n") + "\n\n"
    return head + "".join(x for k, x in enumerate(secs) if k not in moved_idx), arch


def apply_gen(text: str, name: str, body: str) -> str:
    def f(m):
        return m.group(1) + body + m.group(4) if m.group("name") == name else m.group(0)
    return GEN.sub(f, text)


def plan_gen(host: Host) -> dict[Path, str]:
    """Return {path: new_text} for every file whose generated content differs."""
    out: dict[Path, str] = {}
    def stage(p: Path, name: str, body: str):
        cur = out.get(p) or (read(p) if p.is_file() else "")
        if f"<!-- sdd:gen {name} -->" not in cur:
            return
        new = apply_gen(cur, name, body)
        if new != (read(p) if p.is_file() else ""):
            out[p] = new
    for v in versions(host):
        p = v / "README.md"
        t = read(p)
        fm, end = front_matter(t)
        d = derived_version_status(v)
        if end and fm.get("status") != d:
            out[p] = set_front(t, "status", d)
    stage(host.docs / "iterations/README.md", "iterations", gen_iterations(host))
    stage(host.docs / "reports/README.md", "reports", gen_reports(host))
    stage(host.docs / "operations/incidents/README.md", "incidents", gen_incidents(host))
    if host.gap_dir:
        stage(host.gap_register, "gaps", gen_gaps(host))
    hp = host.docs / "handoff.md"
    if hp.is_file():
        stage(hp, "handoff-active", gen_handoff_active(host))
        cur = out.get(hp) or read(hp)
        new, arch = rotate_handoff(host, cur)
        if arch:
            out[hp] = new
            for ap, add in arch.items():
                base = out.get(ap) or (read(ap) if ap.is_file() else f"# 交接历史归档：{ap.stem[-7:]}\n\n")
                out[ap] = base.rstrip("\n") + "\n\n" + add
    return out


# ----------------------------------------------------------------------------- check
class Report:
    def __init__(self, focus: set[str] | None):
        self.focus = focus
        self.errors = 0
        self.warns = 0

    def add(self, level: str, rule: str, path: str, msg: str, fix: str = "", force: bool = False):
        if level == "ERROR" and not force and self.focus is not None and path not in self.focus and not path.startswith("*"):
            level = "WARN"
        if level == "ERROR":
            self.errors += 1
        else:
            self.warns += 1
        print(f"{level} {rule} {path}: {msg}" + (f" → {fix}" if fix else ""))


def is_new(host: Host, p: Path, cache: dict) -> bool:
    if p in cache:
        return cache[p]
    d = added_date(host, p)
    cache[p] = d is None or (bool(host.strict_since) and d >= host.strict_since)
    return cache[p]


def check(host: Host, focus: set[str] | None, today: str, deleted: set[str] | None = None) -> int:
    r = Report(focus)
    D = host.docs
    newc: dict = {}
    arch = host.archive

    def in_arch(p: Path) -> bool:
        return arch in p.resolve().parents

    # C1 + C2 + C3: typed documents
    deleted = deleted or set()

    def need(p: Path, keys: tuple, rule="C1", typ: str | None = None):
        fm, _ = front_matter(read(p))
        miss = [k for k in keys if not fm.get(k)]
        lvl = "ERROR" if is_new(host, p, newc) else "WARN"
        if miss:
            r.add(lvl, rule, host.rel(p), f"头部缺字段或为空 {', '.join(miss)}", "补齐 front matter")
        if typ and fm.get("type") and fm["type"] != typ:
            r.add(lvl, rule, host.rel(p), f"type `{fm['type']}` 应为 `{typ}`")
        if len(fm.get("owner", "")) > 40:
            r.add("ERROR", rule, host.rel(p), "owner 应是负责人名称，不是一句话", "截成负责人，说明写进正文")
        return fm

    def valid_date(v: str) -> bool:
        try:
            dt.date.fromisoformat(v); return True
        except ValueError:
            return False

    def work_extras(p: Path, fm: dict, gap: bool):
        st = fm.get("status")
        if st not in WORK:
            r.add("ERROR", "C2", host.rel(p), f"状态 `{st}` 不在工作项词表 {'/'.join(WORK)}", "改用词表词")
            return
        req = {"parked": ("restart", "review"), "dropped": ("reason",), "merged": ("merged-into",)}.get(st, ())
        if gap and st == "planned":
            req = ("version",)
        if gap and st in ("open", "shaping", "ready"):
            req = ("review",)
        if gap and st == "done":
            req = ("released",)
        miss = [k for k in req if not fm.get(k)]
        if miss:
            r.add("ERROR", "C2", host.rel(p), f"`{st}` 必须写 {', '.join(miss)}")
        if fm.get("review") and not valid_date(fm["review"]):
            r.add("ERROR", "C2", host.rel(p), f"复审日 `{fm['review']}` 不是 YYYY-MM-DD 日期")
        if gap and st == "done" and fm.get("released") not in (None, "", "true", "false", "unknown"):
            r.add("ERROR", "C2", host.rel(p), "released 只能是 true / false / unknown")
        if gap and st == "done" and fm.get("released") == "unknown":
            r.add("WARN", "C8", host.rel(p), "已结束但是否已随 origin/main 上线未核实（released: unknown）")

    for v in versions(host):
        rp = v / "README.md"
        fm = need(rp, ("title", "type", "status", "owner", "updated"), typ="iteration")
        st = fm.get("status")
        d = derived_version_status(v)
        if st not in VERSION_STATES:
            r.add("ERROR", "C2", host.rel(rp), f"版本状态 `{st}` 不在 {'/'.join(VERSION_STATES)}", "运行 gen")
        elif st != d:
            r.add("ERROR", "C3", host.rel(rp), f"版本状态 `{st}` 与 Spec 推导结果 `{d}` 不一致", "运行 gen")
        for q in sorted(v.glob("*.md")):
            if q.name == "README.md":
                continue
            qf = need(q, ("title", "type", "owner", "updated"), typ="iteration")
            if "status" in qf:
                r.add("ERROR", "C3", host.rel(q), "版本内非 README 文档不写状态", "删掉 status 行")
        for vm in sorted(v.glob("*/VERSION.md")):
            s = spec_status(vm)
            if s not in SPEC:
                r.add("ERROR", "C2", host.rel(vm), f"Spec 状态 `{s}` 不在 {'/'.join(SPEC)}")

    for sub, keys in (("operations/requests", ("title", "type", "status", "owner", "updated")),
                      ("operations/incidents", ("title", "type", "status", "owner", "updated"))):
        base = D / sub
        if not base.is_dir():
            continue
        cands = [p for p in base.glob("*.md") if p.name != "README.md" and not p.name.startswith("_")]
        cands += [p / "README.md" for p in base.iterdir() if p.is_dir() and (p / "README.md").is_file()
                  and re.match(r"\d{8}-", p.name)]
        for p in sorted(cands):
            fm = need(p, keys, typ=TYPE_OF[sub])
            if "status" in fm:
                work_extras(p, fm, gap=False)

    for name, p, entry in report_entries(host):
        fm, _ = front_matter(read(entry))
        if "status" in fm:
            r.add("ERROR", "C3", host.rel(entry), "报告是记录类，不写状态", "删掉 status；被推翻用 superseded-by")
        need(entry, ("title", "type", "owner", "updated", "topic"), typ="report")
        if not re.search(r"-\d{8}(\.md|/)?$", name):
            r.add("ERROR", "C9", host.rel(p), "报告名必须是 <主题>-<YYYYMMDD>", "用 mv 改名")

    for p in sorted((D / "product").glob("C*.md")) if (D / "product").is_dir() else []:
        if re.search(r"^\|\s*\**状态\**\s*\|", read(p), re.M):
            r.add("ERROR", "C3", host.rel(p), "能力页是常青文档，不写状态行", "删掉状态行")

    gp = gap_files(host)
    seen_gap = set()
    for p in gp:
        fm = need(p, ("id", "title", "type", "status", "severity", "owner", "created"), typ="gap")
        if fm.get("id") and fm["id"] != p.stem:
            r.add("ERROR", "C10", host.rel(p), f"文件名 {p.stem} 与 id {fm['id']} 不一致")
        if p.stem in seen_gap:
            r.add("ERROR", "C10", host.rel(p), "编号重复")
        seen_gap.add(p.stem)
        work_extras(p, fm, gap=True)
        rv = fm.get("review")
        if rv and fm.get("status") in WORK_LIVE + ("parked",) and rv <= today:
            r.add("WARN", "C8", host.rel(p), f"复审日 {rv} 已过", "进月度复审")

    dp, header, rows = demand_rows(host)
    if header is not None:
        if tuple(header) != DEM_COLS:
            r.add("ERROR", "C2", host.rel(dp), f"条目表头应为 {' | '.join(DEM_COLS)}")
        ids = set()
        for row in rows:
            i = row.get("ID", "")
            if not re.fullmatch(r"DEM-\d{3}", i):
                r.add("ERROR", "C10", host.rel(dp), f"编号 `{i}` 不是 DEM-NNN")
            if i in ids:
                r.add("ERROR", "C10", host.rel(dp), f"编号 {i} 重复")
            ids.add(i)
            st = strip_md(row.get("状态", "")).split("（")[0].strip()
            note, rv, src = row.get("说明", ""), strip_md(row.get("复审日", "")), row.get("真源 / 版本 / 报告", "")
            if st not in WORK:
                r.add("ERROR", "C2", host.rel(dp), f"{i} 状态 `{st}` 不在工作项词表")
                continue
            if st in ("parked", "dropped", "merged") and not note:
                r.add("ERROR", "C2", host.rel(dp), f"{i} `{st}` 必须在「说明」写重启条件 / 原因 / 去向")
            if st in ("parked",) + WORK_LIVE[:3] and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", rv):
                r.add("ERROR", "C2", host.rel(dp), f"{i} `{st}` 必须有复审日 YYYY-MM-DD")
            elif rv and st in ("parked",) + WORK_LIVE[:3] and rv <= today:
                r.add("WARN", "C8", host.rel(dp), f"{i} 复审日 {rv} 已过", "进月度复审")
            if st == "planned" and "iterations/" not in src:
                r.add("ERROR", "C2", host.rel(dp), f"{i} `planned` 必须链到版本目录")

    for v in versions(host):
        if derived_version_status(v) == "active":
            d0 = added_date(host, v / "README.md")
            if d0 and (dt.date.fromisoformat(today) - dt.date.fromisoformat(d0)).days > VERSION_MAX_DAYS:
                r.add("WARN", "C8", host.rel(v / "README.md"), f"版本自 {d0} 起未关，超过 {VERSION_MAX_DAYS} 天", "进月度复审")

    # C4 generated sections: markers well-formed and balanced, content up to date
    for p in [x for x in md_files(D) if not in_arch(x)]:
        t = strip_code(read(p))
        if "sdd:gen" not in t:
            continue
        stack: list[str] = []
        for m in MARKER.finditer(t):
            g = GOOD_MARKER.fullmatch(m.group(0))
            line = t[:m.start()].count("\n") + 1
            if not g:
                r.add("ERROR", "C4", host.rel(p), f"第 {line} 行生成标记格式错误 `{m.group(0)}`", "写成 <!-- sdd:gen NAME --> / <!-- /sdd:gen NAME -->")
                continue
            close, name = g.group(1) == "/", g.group(2)
            if not close:
                stack.append(name)
            elif not stack or stack.pop() != name:
                r.add("ERROR", "C4", host.rel(p), f"第 {line} 行生成标记 `{name}` 未配对")
        for name in stack:
            r.add("ERROR", "C4", host.rel(p), f"生成标记 `{name}` 缺结束标记")
    for p in plan_gen(host):
        r.add("ERROR", "C4", host.rel(p), "生成内容过期或被手改", "运行 sdd_docs.py gen")

    # C5 links (inline, angle-bracket and reference-style; code spans ignored; anchors checked)
    from urllib.parse import unquote
    hist = 0
    for p in list(md_files(D)) + [host.root / "AGENTS.md"]:
        if not p.is_file():
            continue
        historical = in_arch(p) or (D / "reports") in p.parents
        for t, anc in link_targets(read(p)):
            if is_external(t):
                continue
            path = unquote(re.split(r"[?]", t, maxsplit=1)[0])
            tgt = os.path.normpath(os.path.join(p.parent, path)) if path else ""
            if path and not os.path.exists(tgt):
                gone = host.rel(Path(tgt)) in deleted if tgt.startswith(str(host.root)) else False
                if historical and not gone:
                    hist += 1
                else:
                    r.add("ERROR", "C5", host.rel(p), f"断链 {t}" + ("（目标在本次提交中被删除或移走）" if gone else ""),
                          "改链接或用 mv 移动", force=gone)
            elif anc and tgt.endswith(".md") and os.path.isfile(tgt) and not historical \
                    and not anchor_ok(Path(tgt), anc[1:]):
                r.add("ERROR", "C5", host.rel(p), f"锚点不存在 {t}{anc}", "改成目标文件里实际的标题锚点")
        if not historical:
            for anc in re.findall(r"\]\(#([^)\s]+)\)", strip_code(read(p))):
                if not anchor_ok(p, anc):
                    r.add("ERROR", "C5", host.rel(p), f"本页锚点不存在 #{anc}", "改成本页实际的标题锚点")
    if hist:
        r.add("WARN", "C5", "*history", f"历史区（归档、报告）断链 {hist} 条")

    # C6 legacy paths in rule-bearing files
    rule_files = [host.root / "AGENTS.md"]
    for g in (".cursor/rules/*.mdc", ".agents/skills/**/*.md"):
        rule_files += sorted(host.root.glob(g))
    rule_files += [p for p in D.rglob("README.md") if not in_arch(p) and (D / "reports") not in p.parents
                   and (D / "iterations") not in p.parents]
    rule_files += [D / "iterations/README.md"] if (D / "iterations/README.md").is_file() else []
    for p in rule_files:
        if not p.is_file() or "design-system" in p.parts:
            continue
        t = read(p)
        for pat in host.legacy:
            for m in re.finditer(r"(?<![\w/<>.-])" + re.escape(pat), t):
                line = t[:m.start()].count("\n") + 1
                if re.match(r"\s*-\s*SDD legacy paths:", t.splitlines()[line - 1]):
                    continue
                r.add("ERROR", "C6", host.rel(p), f"第 {line} 行引用已退役路径 `{pat}`", "改为现行路径")

    # C7 size budgets
    def budget(p: Path, limit: int):
        if p.is_file() and p.stat().st_size > limit:
            r.add("ERROR", "C7", host.rel(p), f"{p.stat().st_size // 1024}KB 超过上限 {limit // 1024}KB", "拆分子页或精简")
    budget(host.root / "AGENTS.md", BUDGET_AGENTS)
    budget(D / "handoff.md", BUDGET_HANDOFF)
    for p in sorted((D / "product").glob("C*.md")) if (D / "product").is_dir() else []:
        budget(p, BUDGET_HUB)
    gen_targets = {host.gap_register.resolve()}
    for sub in ("product", "architecture", "guides", "contracts"):
        for p in md_files(D / sub) if (D / sub).is_dir() else []:
            rp = host.rel(p)
            if p.resolve() in gen_targets or any(fnmatch.fnmatch(rp, g) for g in host.size_exempt):
                continue
            if host.gap_dir and host.gap_dir in p.parents:
                continue
            if re.match(r"C\d", p.name) and p.parent == D / "product":
                continue
            budget(p, BUDGET_EVERGREEN)

    # C9 placement
    readme = D / "README.md"
    rt = read(readme) if readme.is_file() else ""
    for d in sorted(x for x in D.iterdir() if x.is_dir() and not x.name.startswith((".", "_"))):
        if not re.search(rf"`{re.escape(d.name)}/", rt):
            r.add("ERROR", "C9", host.rel(d), "顶层目录未在 docs/README.md 放置表中声明")
    for d in sorted(D.rglob("*")):
        if not d.is_dir() or in_arch(d) or d == arch:
            continue
        rel_parts = d.relative_to(D).parts
        if rel_parts[0] in ("iterations", "contracts") or any(x.startswith((".", "_")) for x in rel_parts):
            continue
        if len(rel_parts) < 2 or len(rel_parts) > 3:
            continue
        kids = [x for x in d.iterdir() if not x.name.startswith(".")]
        if len(kids) == 1 and kids[0].is_file():
            r.add("ERROR", "C9", host.rel(d), "单文件目录", f"改成单个文件 {d.name}.md")
    for d in sorted(D.rglob("*")):
        if d.is_dir() and d.name in ("_archive", "archive", host.archive.name) and d.resolve() != arch.resolve() \
                and not in_arch(d) and d != arch and (D / "specs") not in d.parents:
            r.add("ERROR", "C9", host.rel(d), "子目录里不另建归档目录（六条规则第 4 条）", f"移入 {host.rel(arch)}/ 并保留原相对路径")
    if host.gap_dir and host.gap_dir.is_dir():
        for x in sorted(host.gap_dir.iterdir()):
            if not re.fullmatch(r"GAP-[A-Za-z0-9-]+\.md|_template\.md", x.name):
                r.add("ERROR", "C9", host.rel(x), "gap 目录只放 GAP-NNN.md", "改名为 GAP-<编号>.md 或移出")
    tpl = PLUGIN / "templates/docs"
    for t in tpl.rglob("_template*"):
        twin = D / t.relative_to(tpl)
        if twin.exists():
            r.add("ERROR", "C9", host.rel(twin), "插件已有此模板，宿主不留副本", "删除，改用插件模板")

    # C10 ADR numbers
    for adr_dir in (D / "architecture/09-decisions", D / "product/decisions"):
        if adr_dir.is_dir():
            nums: dict[str, str] = {}
            for p in sorted(adr_dir.glob("[0-9][0-9][0-9]-*.md")):
                n = p.name[:3]
                if n in nums:
                    r.add("ERROR", "C10", host.rel(p), f"ADR 编号 {n} 与 {nums[n]} 重复")
                nums[n] = p.name

    print(f"sdd-docs: errors={r.errors} warnings={r.warns}")
    return 1 if r.errors else 0


# ----------------------------------------------------------------------------- mv
def mv(host: Host, pairs: list[tuple[str, str]]) -> int:
    """Atomic-ish: validate every pair first, roll back moves already made if one fails, then relink."""
    root = host.root
    pairs = [(a.rstrip("/"), b.rstrip("/")) for a, b in pairs]
    srcs, dsts = [a for a, _ in pairs], [b for _, b in pairs]
    problems = []
    if len(set(srcs)) != len(srcs) or len(set(dsts)) != len(dsts):
        problems.append("源或目标重复")
    for a, b in pairs:
        if not (root / a).exists():
            problems.append(f"源不存在 {a}")
        elif not git(host, "ls-files", "--", a).strip():
            problems.append(f"源未被 git 跟踪 {a}")
        if (root / b).exists():
            problems.append(f"目标已存在 {b}")
        if b == a or b.startswith(a + "/"):
            problems.append(f"目标在源内部 {b}")
    if problems:
        for x in problems:
            print(f"mv: {x}", file=sys.stderr)
        return 2
    done: list[tuple[str, str]] = []
    for a, b in pairs:
        (root / b).parent.mkdir(parents=True, exist_ok=True)
        res = subprocess.run(["git", "-C", str(root), "mv", a, b], capture_output=True, text=True)
        if res.returncode:
            for x, y in reversed(done):
                subprocess.run(["git", "-C", str(root), "mv", y, x], capture_output=True)
            print(f"mv: git mv {a} 失败，已回滚：{res.stderr.strip()}", file=sys.stderr)
            return 2
        done.append((a, b))
    def mp(p: str) -> str:
        for a, b in pairs:
            if p == a or p.startswith(a + "/"):
                return b + p[len(a):]
        return p
    def old_of(n: str) -> str:
        for a, b in pairs:
            if n == b or n.startswith(b + "/"):
                return a + n[len(b):]
        return n
    files = [f for f in subprocess.run(["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                       capture_output=True, text=True).stdout.split("\0") if f]
    record_dirs = (host.rel(host.archive) + "/", host.rel(host.docs / "reports") + "/")
    changed = 0
    for f in files:
        fp = root / f
        if not (f.endswith(TEXT_EXTS) or os.path.basename(f).startswith(TEXT_NAMES)) or not fp.is_file() or "node_modules" in f:
            continue
        try:
            with open(fp, encoding="utf-8", newline="") as fh:
                s_ = fh.read()
        except UnicodeDecodeError:
            continue
        o = s_
        of = old_of(f)
        if f.endswith((".md", ".mdc")):
            def fix(m):
                t = link_path(m)
                if is_external(t):
                    return m.group(0)
                r_ = os.path.normpath(os.path.join(os.path.dirname(of), t))
                nr = mp(r_)
                if nr == r_ and of == f:
                    return m.group(0)
                new = os.path.relpath(nr, os.path.dirname(f))
                if t.endswith("/") and not new.endswith("/"):
                    new += "/"
                return fmt_link(new, m.group("anc") or "", m.group("ap") is not None)
            s_ = LINK.sub(fix, s_)
            def fixdef(m):
                t = m.group("p")
                if is_external(t):
                    return m.group(0)
                r_ = os.path.normpath(os.path.join(os.path.dirname(of), t))
                nr = mp(r_)
                if nr == r_ and of == f:
                    return m.group(0)
                return m.group(0).replace(t, os.path.relpath(nr, os.path.dirname(f)), 1)
            s_ = REFDEF.sub(fixdef, s_)
        if not f.startswith(record_dirs):
            for a, b in pairs:
                s_ = re.sub(r"(?<![\w/.-])" + re.escape(a) + r"(?=/|(?![\w.-]))", b, s_)
        if s_ != o:
            write(fp, s_)
            changed += 1
    print(f"mv: {len(pairs)} 项已移动，{changed} 个文件改写引用")
    return 0


# ----------------------------------------------------------------------------- main
def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[0] not in ("check", "gen", "mv"):
        print(__doc__); return 2
    cmd, host = argv[0], Host(Path(argv[1]))
    rest = argv[2:]
    if not host.docs.is_dir():
        print(f"sdd-docs: docs root not found: {host.docs}", file=sys.stderr); return 2
    if cmd == "check":
        focus = None
        today = dt.date.today().isoformat()
        if "--today" in rest:
            today = rest[rest.index("--today") + 1]
        def opt_list(flag):
            if flag not in rest:
                return None
            out = []
            for x in rest[rest.index(flag) + 1:]:
                if x.startswith("--"):
                    break
                out.append(Path(x).as_posix())
            return set(out)
        focus = opt_list("--files")
        return check(host, focus, today, opt_list("--deleted"))
    if cmd == "gen":
        plan = plan_gen(host)
        if "--check" in rest:
            for p in plan:
                print(f"gen: 需要更新 {host.rel(p)}")
            return 1 if plan else 0
        rc = 0
        for p, t in plan.items():
            p.parent.mkdir(parents=True, exist_ok=True)
            if p.is_file():
                with open(p, encoding="utf-8", errors="replace", newline="") as f:
                    now = f.read()
                if now != _ORIG.get(p.resolve(), now):
                    print(f"gen: {host.rel(p)} 在生成期间被修改，跳过；请重跑 gen", file=sys.stderr); rc = 1
                    continue
            write(p, t)
            print(f"gen: 已更新 {host.rel(p)}")
        return rc
    if cmd == "mv":
        if len(rest) < 2 or len(rest) % 2:
            print("mv: 参数必须成对 OLD NEW", file=sys.stderr); return 2
        return mv(host, list(zip(rest[0::2], rest[1::2])))
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
