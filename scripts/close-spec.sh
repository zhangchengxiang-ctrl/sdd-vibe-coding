#!/usr/bin/env bash
# Close a spec version in one command (关版收口).
#
# Does, in order:
#   1. verify-deliver (ship.sh red-green replay, then check_spec --closing)
#   2. VERSION.md 状态 -> archived (+ 变更记录 row)
#   3. A Spec inside a version (docs/iterations/<yyyy-mm>/<w>/<version>/<id>) STAYS where it is:
#      the time-bucketed path is permanent and the status word says it is closed, so nothing
#      moves and no link breaks. Only a legacy docs/specs/<id> (written before the version layer)
#      is moved: git mv docs/specs/<id> -> docs/specs/<archive dir>/<id> (plain mv without git);
#      <archive dir> defaults to `archive`, override with `- SDD archive dir: _archive` in AGENTS.md
#      3b. (legacy only) rewrite markdown links that pointed at the old location (and the moved
#          files' own relative links, one level deeper now)
#   4. wish-journey phase -> acceptance-passed (best-effort)
#   5. (legacy only) List host docs still pointing at the old path (index update is the
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
ARCH_NAME="archive"
if [[ -f "$HOST/AGENTS.md" ]]; then
  found_arch="$(sed -n 's/.*SDD archive dir:[[:space:]]*`\{0,1\}\([^`[:space:]/]\{1,\}\)`\{0,1\}.*/\1/p' "$HOST/AGENTS.md" | head -1 || true)"
  [[ -n "$found_arch" ]] && ARCH_NAME="$found_arch"
fi
SPEC_PATHS="$ROOT/skills/spec/scripts/spec_paths.py"
set +e
found="$(python3 "$SPEC_PATHS" find "$HOST" "$SPEC")"; fst=$?
set -e
if [[ "$fst" -eq 3 ]]; then
  echo "close-spec: FAIL Spec id $SPEC is not unique (see above); rename one of them first" >&2
  exit 1
fi
if [[ "$fst" -ne 0 || -z "$found" ]]; then
  echo "close-spec: FAIL spec dir not found for $SPEC (looked in every version under $docs_root/iterations/, in $docs_root/specs/ and its archive)" >&2
  exit 1
fi
SPEC_DIR="$found"
ITER="$(python3 "$SPEC_PATHS" iteration "$SPEC_DIR")"
ARCH_DIR="$HOST/$docs_root/specs/$ARCH_NAME/$SPEC"
HOST_REAL="$(cd "$HOST" && pwd -P)"

case "$SPEC_DIR" in
  "$HOST_REAL/$docs_root/specs/$ARCH_NAME/"*)
    echo "close-spec: already archived at $SPEC_DIR"
    exit 0 ;;
esac
if [[ -n "$ITER" ]] && python3 - "$SPEC_DIR/VERSION.md" <<'PYST'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"^\|\s*\*{0,2}状态\*{0,2}\s*\|\s*`?([A-Za-z-]+)|^\s*-\s*(?:Status|状态)\s*[:：]\s*`?([A-Za-z-]+)", t, re.M)
sys.exit(0 if m and (m.group(1) or m.group(2)) == "archived" else 1)
PYST
then
  echo "close-spec: already closed (archived in version $ITER): $SPEC_DIR"
  exit 0
fi

# Closing replays the frozen Oracles from evidence that is NOT committed (.codex-dispatch-logs/,
# .sdd-evidence/). On a checkout that lacks it, say so up front instead of letting the replay fail
# halfway with a page of unrelated errors.
if [[ "$SKIP_VD" != "1" && -f "$SPEC_DIR/run.md" ]]; then
  missing_runs=""
  while IFS= read -r rid; do
    [[ -n "$rid" ]] || continue
    if [[ ! -f "$HOST/.codex-dispatch-logs/$rid.jsonl" && ! -f "$HOST/.codex-dispatch-logs/$rid.meta.txt" ]]; then
      missing_runs+="  - $rid"$'\n'
    fi
  done < <(sed -nE 's/^[-*[:space:]]*dispatch-run-id:[[:space:]]*`?([A-Za-z0-9_.-]+)`?.*/\1/p' "$SPEC_DIR/run.md")
  if [[ -n "$missing_runs" ]]; then
    {
      echo "close-spec: FAIL this checkout has no local evidence for the dispatch run(s) named in run.md:"
      printf '%s' "$missing_runs"
      echo "  Closing replays Oracles from .codex-dispatch-logs/ and .sdd-evidence/, which are not committed."
      echo "  Close from the machine that holds them, or restore them first. (--skip-verify-deliver only if"
      echo "  the caller asserts the Spec is already verified.)"
    } >&2
    exit 1
  fi
fi

echo "== close-spec 1/5: verify-deliver =="
if [[ "$SKIP_VD" == "1" ]]; then
  echo "close-spec: skip verify-deliver (caller asserts already closed)"
else
  bash "$ROOT/scripts/verify-deliver.sh" "$HOST" "$SPEC"
fi

echo "== close-spec 2/5: VERSION -> archived =="
VERSION_MD="$SPEC_DIR/VERSION.md"
if [[ ! -f "$VERSION_MD" ]]; then
  echo "close-spec: FAIL missing $VERSION_MD" >&2
  exit 1
fi
python3 - "$VERSION_MD" "$SPEC" "$docs_root" "$ARCH_NAME" "$ITER" <<'PY'
import re, sys
from datetime import date
from pathlib import Path

path, spec, docs_root, arch, it = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
text = path.read_text(encoding="utf-8")

# The whole cell is replaced, so an annotated cell such as "`verifying`（已上线 …）" works too;
# the original text is kept in the change-log row below.
# Three spellings exist in the wild: "| **状态** | … |", "| 状态 | … |" and "- Status: …".
STATUS_PATTERNS = [
    re.compile(r"^(\|\s*\*{0,2}状态\*{0,2}\s*\|\s*)(.*?)(\s*\|?\s*)$", re.M),
    re.compile(r"^(\s*-\s*(?:Status|状态)\s*[:：]\s*)(.*?)(\s*)$", re.M),
]
old = None
for status_re in STATUS_PATTERNS:
    m = status_re.search(text)
    if m:
        old = m.group(2).strip()
        text = status_re.sub(lambda mm: f"{mm.group(1)}`archived`{mm.group(3)}", text, count=1)
        break
if old is None:
    print("close-spec: FAIL cannot locate a 状态 / Status line in VERSION.md "
          "(expected `| **状态** | … |` or `- Status: …`)", file=sys.stderr)
    sys.exit(1)

shown = old.replace("|", "/")
shown = shown if len(shown) <= 120 else shown[:117] + "…"
where = (f"留在版本 `{it}` 目录内（不搬动）" if it else f"搬入 `{docs_root}/specs/{arch}/{spec}/`")
row = f"| {date.today().isoformat()} | 关版：{shown} → `archived`，{where} | close-spec |"
if re.search(r"^## 变更记录", text, re.M):
    text = text.rstrip() + "\n" + row + "\n"
path.write_text(text, encoding="utf-8")
print(f"close-spec: VERSION status {old} -> archived")
PY

if [[ -n "$ITER" ]]; then
  echo "== close-spec 3/5: stays in version $ITER (path is permanent; no move, no link rewrite) =="
else
echo "== close-spec 3/5: move to $ARCH_NAME/ =="
mkdir -p "$(dirname "$ARCH_DIR")"
if git -C "$HOST" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && git -C "$HOST" ls-files --error-unmatch "$docs_root/specs/$SPEC" >/dev/null 2>&1; then
  git -C "$HOST" mv "$docs_root/specs/$SPEC" "$docs_root/specs/$ARCH_NAME/$SPEC"
else
  mv "$SPEC_DIR" "$ARCH_DIR"
fi
echo "close-spec: moved -> $docs_root/specs/$ARCH_NAME/$SPEC/"

echo "== close-spec 3b/5: rewrite links to the new location =="
python3 - "$HOST" "$docs_root" "$SPEC" "$ARCH_NAME" <<'PY'
import os, re, sys
from urllib.parse import unquote

host, docs_root, spec, arch = sys.argv[1:5]
old_dir = os.path.join(host, docs_root, "specs", spec)
new_dir = os.path.join(host, docs_root, "specs", arch, spec)
LINK = re.compile(r"(\]\()([^)\s]+)(\s+\"[^\"]*\")?(\))")
REF = re.compile(r"^(\[[^\]]+\]:\s*)(\S+)", re.M)


def within(p, d):
    return p == d or p.startswith(d + os.sep)


def fix(f, text):
    in_moved = within(f, new_dir)
    f_old_dir = os.path.dirname(os.path.join(old_dir, os.path.relpath(f, new_dir))) if in_moved else os.path.dirname(f)

    def tgt(t):
        if re.match(r"^([A-Za-z][A-Za-z0-9+.-]*:|#|/)", t):
            return t
        m = re.match(r"([^#?]*)([#?].*)?$", t)
        path, anc = m.group(1), m.group(2) or ""
        if not path:
            return t
        abs_old = os.path.normpath(os.path.join(f_old_dir, unquote(path)))
        if not (in_moved or within(abs_old, old_dir)):
            return t
        abs_new = new_dir + abs_old[len(old_dir):] if within(abs_old, old_dir) else abs_old
        rel = os.path.relpath(abs_new, os.path.dirname(f))
        if path.endswith("/") and not rel.endswith("/"):
            rel += "/"
        if path.startswith("./") and not rel.startswith("."):
            rel = "./" + rel
        return t if rel == path else rel + anc

    text = LINK.sub(lambda m: m.group(1) + tgt(m.group(2)) + (m.group(3) or "") + m.group(4), text)
    return REF.sub(lambda m: m.group(1) + tgt(m.group(2)), text)


changed = 0
for base, dirs, files in os.walk(os.path.join(host, docs_root)):
    dirs[:] = [d for d in dirs if d != ".git"]
    for name in files:
        if not name.endswith(".md"):
            continue
        f = os.path.join(base, name)
        try:
            text = open(f, encoding="utf-8").read()
        except Exception:
            continue
        new = fix(f, text)
        if new != text:
            open(f, "w", encoding="utf-8", newline="").write(new)
            changed += 1
print(f"close-spec: rewrote links in {changed} file(s)")
PY
fi

echo "== close-spec 4/5: journey -> acceptance-passed =="
if bash "$ROOT/scripts/wish-journey.sh" --cwd "$HOST" --spec "$SPEC" \
  --set acceptance-passed >/dev/null 2>&1; then
  echo "close-spec: journey phase=acceptance-passed"
else
  echo "close-spec: journey update skipped (non-fatal)"
fi

echo "== close-spec 5/5: stale references (agent must update indexes) =="
if [[ -n "$ITER" ]]; then
  echo "close-spec: nothing moved, no stale references"
else
stale="$(grep -rIl --exclude-dir="$ARCH_NAME" --exclude-dir=.git \
  -e "specs/$SPEC" -e "](\./$SPEC/" -e "](\.\./$SPEC/" "$HOST/$docs_root" 2>/dev/null || true)"
if [[ -n "$stale" ]]; then
  echo "close-spec: these docs still reference $SPEC as active — update them to $ARCH_NAME/:"
  echo "$stale" | sed 's/^/  - /'
else
  echo "close-spec: no stale references found"
fi
fi

echo "close-spec: DONE — 剩余人工步骤：更新宿主索引（如上）；询问是否 Deploy（不自动上生产）"
