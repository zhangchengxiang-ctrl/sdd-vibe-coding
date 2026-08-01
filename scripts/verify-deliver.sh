#!/usr/bin/env bash
# Verify / Deploy close gate: honesty checks + stamp run.md.
#
# Hard gate: before claiming 可交付 / acceptance-passed / prod-smoke 通过,
# Agent must run this script (make verify-deliver) to exit 0.
# On success writes: `verify-deliver: ok · <ISO8601>` into run.md.
#
# Usage:
#   bash scripts/verify-deliver.sh <host-root> <spec-id>
#   make verify-deliver HOST=/path SPEC=id
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -lt 2 ]]; then
  echo "usage: verify-deliver.sh <host-root> <spec-id>" >&2
  exit 2
fi
HOST="$(cd "$1" && pwd)"
SPEC="$2"

echo "== verify-deliver: check_spec (pre-stamp) =="
python3 "$ROOT/skills/spec/scripts/check_spec.py" \
  "$HOST" "$SPEC" --skip-agents --allow-unstamped-deliver

# Extra chat-honesty heuristics + stamp (beyond check_spec)
python3 - "$HOST" "$SPEC" <<'PY'
import re, sys
from datetime import datetime, timezone
from pathlib import Path

host, spec = Path(sys.argv[1]), sys.argv[2]
agents = host / "AGENTS.md"
root_name = "docs"
if agents.is_file():
    m = re.search(r"SDD docs root:\s*`?([^`\n]+)`?", agents.read_text(encoding="utf-8"))
    if m:
        root_name = m.group(1).strip().strip("/")
docs = host / root_name
spec_dir = docs / "specs" / spec
if not spec_dir.is_dir():
    cand = host / spec
    if cand.is_dir():
        spec_dir = cand
run = spec_dir / "run.md"
if not run.is_file():
    print(f"verify-deliver: FAIL missing {run}", file=sys.stderr)
    sys.exit(1)
text = run.read_text(encoding="utf-8")
errs = []

deliver = ""
m = re.search(r"是否可以交付：\s*`?([^`|\n]+)`?", text)
if m:
    deliver = m.group(1).strip()

mode = ""
m = re.search(r"当前模式：\s*`?([^`|\n]+)`?", text)
if m:
    mode = m.group(1).strip().lower()

status = ""
m = re.search(r"-\s*状态：\s*`?([^`|\n]+)`?", text)
if m:
    status = m.group(1).strip().split("|")[0].strip()

acceptance = ""
m = re.search(r"-\s*Acceptance：\s*`?([^`|\n]+)`?", text)
if m:
    acceptance = m.group(1).strip().split("|")[0].strip()

claims_smoke = bool(
    re.search(r"\[部署[^\]]*prod-smoke\s*通过", text)
    or re.search(r"产品冒烟[^：:\n]*[：:][ \t]*通过\b", text)
)
claimed_pass = (
    deliver == "可交付"
    or "acceptance-passed" in status
    or acceptance == "acceptance-passed"
    or claims_smoke
)

if deliver == "可交付":
    if mode and mode not in {"verify", "verifying"} and "verify" not in mode:
        errs.append(
            f"可交付 requires 当前模式=verify (got {mode!r}); Build 轨禁止可交付"
        )
    if not re.search(r"证伪|falsify", text, re.I):
        errs.append("可交付 requires a 证伪/falsify record in run.md (see falsify-checklist)")
    if not re.search(r"已验证的用户结果", text):
        errs.append("可交付 requires 「已验证的用户结果」 section")

# Deploy: P5 filled without P2/P3
p5 = re.search(r"Deploy\s*/\s*rollback（P5）[：:]\s*(\S.+)", text)
p2 = re.search(r"P2 发布方案[^\n]*[：:]\s*(\S.+)", text)
p3 = re.search(r"P3 验证方案[^\n]*[：:]\s*(\S.+)", text)

def filled(m):
    if not m:
        return False
    v = m.group(1).strip()
    return v not in {"", "—", "-", "待填", "n/a", "N/A", "不适用"}

if filled(p5) and (not filled(p2) or not filled(p3)):
    errs.append("Production: Deploy/rollback (P5) filled but P2 or P3 empty — refuse")

def field(prefix):
    m = re.search(rf"{prefix}[^：:\n]*[：:][ \t]*([^\n]*)", text)
    return (m.group(1).strip() if m else "")

if claims_smoke:
    probe = field(r"探活执行者")
    evid = field(r"产品冒烟证据")
    user_act = field(r"需要用户做什么")
    if probe.lower().replace("_", "-") not in {"agent", "blocked-needs-auth"}:
        errs.append("prod-smoke 通过 requires 探活执行者: agent | blocked-needs-auth")
    if not evid or (
        re.search(r"(?i)\bhealth\b|/health|window-smoke", evid)
        and not re.search(
            r"(?i)kind\s*=\s*(browser-job|api-diff|network-har|integration|unit)",
            evid,
        )
    ):
        errs.append("prod-smoke 通过 requires strong 产品冒烟证据 (kind=…)")
    if re.search(r"硬刷|打开浏览器|打开页面|请.*刷新|开无痕", user_act):
        errs.append("prod-smoke 通过 forbids user-as-canary 需要用户做什么")

if deliver == "可交付":
    for m in re.finditer(
        r"需要用户做什么[：:][ \t]*([^\n]+)|下一步[：:][ \t]*([^\n]+)", text
    ):
        act = (m.group(1) or m.group(2) or "").strip()
        if re.search(r"硬刷|打开浏览器|打开页面|请.*刷新|开无痕", act):
            errs.append(f"可交付 forbids user-as-canary step: {act!r}")

if errs:
    for e in errs:
        print(f"verify-deliver: FAIL {e}", file=sys.stderr)
    sys.exit(1)

# Stamp close-gate record (Nail 1). Always stamp on success so chat can claim.
stamp_line = f"verify-deliver: ok · {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}"
stamp_re = re.compile(r"^([ \t]*[-*]?\s*)?verify-deliver\s*:\s*.+$", re.I | re.M)
if stamp_re.search(text):
    text = stamp_re.sub(rf"\1{stamp_line}", text, count=1)
else:
    # Prefer 关版/结论 block; else append under 关版
    insert = f"- {stamp_line}\n"
    if re.search(r"### 结论\n", text):
        text = re.sub(
            r"(### 结论\n)",
            rf"\1{insert}",
            text,
            count=1,
        )
    elif re.search(r"## 关版\n", text):
        text = re.sub(
            r"(## 关版\n)",
            rf"\1\n### 结论\n{insert}",
            text,
            count=1,
        )
    else:
        text = text.rstrip() + f"\n\n## 关版\n\n### 结论\n{insert}"

run.write_text(text, encoding="utf-8")
print(f"verify-deliver: stamped `{stamp_line}`")
if not claimed_pass:
    print(
        "verify-deliver: note — no 可交付/acceptance-passed/prod-smoke 通过 claim yet; "
        "stamp still written after honesty pass"
    )
print("verify-deliver: ok")
sys.exit(0)
PY

echo "== verify-deliver: check_spec (post-stamp) =="
python3 "$ROOT/skills/spec/scripts/check_spec.py" \
  "$HOST" "$SPEC" --skip-agents
