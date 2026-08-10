#!/usr/bin/env bash
# Close a spec version in one command (关版收口).
#
# Does, in order:
#   1. verify-deliver (Nail 1 honesty gate + stamp run.md)
#   2. VERSION.md 状态 -> archived (+ 变更记录 row)
#   3. git mv docs/specs/<id> -> docs/specs/archive/<id> (plain mv without git)
#   4. wish-journey phase -> acceptance-passed (best-effort)
#   5. List host docs still pointing at the old path (index update is the
#      agent's remaining duty; this script never edits host indexes)
#
# It does NOT deploy. 关版 ≠ 上线.
#
# Usage:
#   bash scripts/close-spec.sh <host-root> <spec-id> [--skip-verify-deliver]
#   make close-spec HOST=/path SPEC=id
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -lt 2 ]]; then
  echo "usage: close-spec.sh <host-root> <spec-id> [--skip-verify-deliver]" >&2
  exit 2
fi
HOST="$(cd "$1" && pwd)"
SPEC="$2"
SKIP_VD=0
[[ "${3:-}" == "--skip-verify-deliver" ]] && SKIP_VD=1

docs_root="docs"
if [[ -f "$HOST/AGENTS.md" ]]; then
  found="$(sed -n 's/.*SDD docs root:[[:space:]]*`\{0,1\}\([^`[:space:]]\{1,\}\)`\{0,1\}.*/\1/p' "$HOST/AGENTS.md" | head -1 || true)"
  [[ -n "$found" ]] && docs_root="${found%/}"
fi
SPEC_DIR="$HOST/$docs_root/specs/$SPEC"
ARCH_DIR="$HOST/$docs_root/specs/archive/$SPEC"

if [[ -d "$ARCH_DIR" && ! -d "$SPEC_DIR" ]]; then
  echo "close-spec: already archived at $ARCH_DIR"
  exit 0
fi
if [[ ! -d "$SPEC_DIR" ]]; then
  echo "close-spec: FAIL spec dir not found: $SPEC_DIR" >&2
  exit 1
fi

echo "== close-spec 1/5: verify-deliver =="
if [[ "$SKIP_VD" == "1" ]]; then
  if ! grep -q "verify-deliver: ok" "$SPEC_DIR/run.md" 2>/dev/null; then
    echo "close-spec: FAIL --skip-verify-deliver but run.md has no verify-deliver stamp" >&2
    exit 1
  fi
  echo "close-spec: skip (stamp already present)"
else
  bash "$ROOT/scripts/verify-deliver.sh" "$HOST" "$SPEC"
fi

echo "== close-spec 2/5: VERSION -> archived =="
VERSION_MD="$SPEC_DIR/VERSION.md"
if [[ ! -f "$VERSION_MD" ]]; then
  echo "close-spec: FAIL missing $VERSION_MD" >&2
  exit 1
fi
python3 - "$VERSION_MD" "$SPEC" "$docs_root" <<'PY'
import re, sys
from datetime import date
from pathlib import Path

path, spec, docs_root = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")

status_re = re.compile(r"(\|\s*\*\*状态\*\*\s*\|\s*)`?([^`|]+?)`?(\s*\|)")
m = status_re.search(text)
if m:
    old = m.group(2).strip()
    text = status_re.sub(lambda mm: f"{mm.group(1)}`archived`{mm.group(3)}", text, count=1)
else:
    old = "?"
    plain = re.compile(r"(状态[：:]\s*)`?([a-z-]+)`?")
    m2 = plain.search(text)
    if not m2:
        print("close-spec: FAIL cannot locate 状态 field in VERSION.md", file=sys.stderr)
        sys.exit(1)
    old = m2.group(2)
    text = plain.sub(lambda mm: f"{mm.group(1)}`archived`", text, count=1)

row = f"| {date.today().isoformat()} | 关版：`{old}` → `archived`，搬入 `{docs_root}/specs/archive/{spec}/` | close-spec |"
if re.search(r"^## 变更记录", text, re.M):
    text = text.rstrip() + "\n" + row + "\n"
path.write_text(text, encoding="utf-8")
print(f"close-spec: VERSION status {old} -> archived")
PY

echo "== close-spec 3/5: move to archive/ =="
mkdir -p "$(dirname "$ARCH_DIR")"
if git -C "$HOST" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && git -C "$HOST" ls-files --error-unmatch "$docs_root/specs/$SPEC" >/dev/null 2>&1; then
  git -C "$HOST" mv "$docs_root/specs/$SPEC" "$docs_root/specs/archive/$SPEC"
else
  mv "$SPEC_DIR" "$ARCH_DIR"
fi
echo "close-spec: moved -> $docs_root/specs/archive/$SPEC/"

echo "== close-spec 4/5: journey -> acceptance-passed =="
if bash "$ROOT/scripts/wish-journey.sh" --cwd "$HOST" --spec "$SPEC" \
  --set acceptance-passed >/dev/null 2>&1; then
  echo "close-spec: journey phase=acceptance-passed"
else
  echo "close-spec: journey update skipped (non-fatal)"
fi

echo "== close-spec 5/5: stale references (agent must update indexes) =="
stale="$(grep -rIl --exclude-dir=archive --exclude-dir=.git \
  -e "specs/$SPEC" -e "](\./$SPEC/" -e "](\.\./$SPEC/" "$HOST/$docs_root" 2>/dev/null || true)"
if [[ -n "$stale" ]]; then
  echo "close-spec: these docs still reference $SPEC as active — update them to archive/:"
  echo "$stale" | sed 's/^/  - /'
else
  echo "close-spec: no stale references found"
fi

echo "close-spec: DONE — 剩余人工步骤：更新宿主索引（如上）；询问是否 Deploy（不自动上生产）"
