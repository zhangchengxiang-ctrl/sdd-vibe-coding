#!/usr/bin/env bash
# Orphan references: every skills/*/references/*.md (except fixtures/_archive)
# must be reachable within 2 hops from some SKILL.md.
#
# Usage:
#   bash scripts/orphan-refs.sh [--count|--strict]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE=report
for arg in "$@"; do
  case "$arg" in
    --count) MODE=count ;;
    --strict) MODE=strict ;;
  esac
done

tmp=$(mktemp)
python3 - "$tmp" <<'PY'
import sys
from pathlib import Path
import re

out_path = Path(sys.argv[1])
root = Path(".").resolve()
link_re = re.compile(r"\]\(([^)]+\.md)[^)]*\)")

def resolve(base: Path, link: str):
    link = link.split("#")[0].strip()
    if not link or link.startswith("http"):
        return None
    p = (base / link).resolve()
    return p if p.is_file() else None

skills = list(Path("skills").rglob("SKILL.md"))
reachable = set()
frontier = []
for s in skills:
    sp = s.resolve()
    reachable.add(sp)
    frontier.append(sp)

for _ in range(3):
    nxt = []
    for f in frontier:
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in link_re.finditer(text):
            r = resolve(f.parent, m.group(1))
            if r and r not in reachable:
                reachable.add(r)
                nxt.append(r)
    frontier = nxt

orphans = []
for f in sorted(Path("skills").glob("*/references/**/*.md")):
    s = str(f).replace("\\", "/")
    if "/_archive/" in s or "/fixtures/" in s:
        continue
    if f.resolve() not in reachable:
        orphans.append(s)

out_path.write_text(str(len(orphans)) + "\n" + "\n".join(orphans) + ("\n" if orphans else ""), encoding="utf-8")
PY

count=$(head -1 "$tmp" | tr -d '[:space:]')
list=$(tail -n +2 "$tmp" || true)
rm -f "$tmp"

if [[ "$MODE" == "count" ]]; then
  echo "$count"
  exit 0
fi

echo "== orphan-refs orphans=$count =="
if [[ -n "${list:-}" ]]; then
  printf '%s\n' "$list"
fi

if [[ "$MODE" == "strict" ]]; then
  [[ "$count" == "0" ]]
else
  exit 0
fi
