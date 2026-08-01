#!/usr/bin/env bash
# Close the Verify shallow-pass gap: check_spec honesty + deliver-mode gates.
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

echo "== verify-deliver: check_spec =="
python3 "$ROOT/skills/spec/scripts/check_spec.py" "$HOST" "$SPEC" --skip-agents

# Extra chat-honesty heuristics on run.md (beyond check_spec)
python3 - "$HOST" "$SPEC" <<'PY'
import re, sys
from pathlib import Path

host, spec = Path(sys.argv[1]), sys.argv[2]
# resolve SDD root like check_spec
agents = host / "AGENTS.md"
root_name = "docs"
if agents.is_file():
    m = re.search(r"SDD docs root:\s*`?([^`\n]+)`?", agents.read_text(encoding="utf-8"))
    if m:
        root_name = m.group(1).strip().strip("/")
docs = host / root_name
spec_dir = docs / "specs" / spec
if not spec_dir.is_dir():
    # allow absolute-ish
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

if errs:
    for e in errs:
        print(f"verify-deliver: FAIL {e}", file=sys.stderr)
    sys.exit(1)
print("verify-deliver: ok")
sys.exit(0)
PY
