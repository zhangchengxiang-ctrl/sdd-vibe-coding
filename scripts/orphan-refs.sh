#!/usr/bin/env bash
# Orphan + broken outbound refs under skills/.
# - Orphan: references/*.md (except fixtures/_archive) unreachable within 2 hops of SKILL.md
# - Broken: relative *.md link target missing (skips http, _archive, fixtures)
# - Unwired: skills/*/scripts/* named nowhere else. An unreachable script looks
#   like coverage and is not; 454 lines of live selftest sat that way unnoticed.
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
import re
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
link_re = re.compile(r"\]\(([^)]+)\)")

def skip_path(s: str) -> bool:
    s = s.replace("\\", "/")
    return "/_archive/" in s or "/fixtures/" in s

def resolve(base: Path, link: str):
    link = link.split("#")[0].split("?")[0].strip()
    if not link or link.startswith(("http://", "https://", "mailto:")):
        return None, "skip"
    if not link.endswith(".md"):
        return None, "skip"
    p = (base / link).resolve()
    try:
        p.relative_to(Path(".").resolve())
    except ValueError:
        return None, "broken"
    return (p if p.is_file() else None), ("ok" if p.is_file() else "broken")

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
            r, st = resolve(f.parent, m.group(1))
            if st == "ok" and r not in reachable:
                reachable.add(r)
                nxt.append(r)
    frontier = nxt

orphans = []
for f in sorted(Path("skills").glob("*/references/**/*.md")):
    s = str(f).replace("\\", "/")
    if skip_path(s):
        continue
    if f.resolve() not in reachable:
        orphans.append(s)

broken = []
for f in sorted(Path("skills").rglob("*.md")):
    s = str(f).replace("\\", "/")
    if skip_path(s):
        continue
    try:
        lines = f.read_text(encoding="utf-8", errors="ignore").splitlines()
    except OSError:
        continue
    for i, line in enumerate(lines, 1):
        for m in link_re.finditer(line):
            raw = m.group(1)
            _, st = resolve(f.parent, raw)
            if st == "broken":
                target = raw.split("#")[0].split("?")[0].strip()
                broken.append(f"{s}:{i} -> {target}")

unwired = []
corpus = []
for f in list(Path("skills").rglob("*.md")) + list(Path("scripts").rglob("*")) \
        + [Path("Makefile"), Path("ARCHITECTURE.md"), Path("README.md")]:
    if f.is_file() and not skip_path(str(f)):
        try:
            corpus.append(f.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            pass
for f in sorted(Path("skills").glob("*/scripts/*")):
    s = str(f).replace("\\", "/")
    if not f.is_file() or skip_path(s) or f.suffix == ".pyc":
        continue
    stem = f.stem
    if not any(stem in text for text in corpus):
        unwired.append(s)

total = len(orphans) + len(broken) + len(unwired)
parts = [str(total)]
if orphans:
    parts.append("ORPHANS:")
    parts.extend(orphans)
if broken:
    parts.append("BROKEN:")
    parts.extend(broken)
if unwired:
    parts.append("UNWIRED:")
    parts.extend(unwired)
out_path.write_text("\n".join(parts) + ("\n" if total or orphans or broken else "\n"), encoding="utf-8")
PY

count=$(head -1 "$tmp" | tr -d '[:space:]')
list=$(tail -n +2 "$tmp" || true)
rm -f "$tmp"

if [[ "$MODE" == "count" ]]; then
  echo "$count"
  exit 0
fi

echo "== orphan-refs orphans+broken+unwired=$count =="
if [[ -n "${list:-}" ]]; then
  printf '%s\n' "$list"
fi

if [[ "$MODE" == "strict" ]]; then
  [[ "$count" == "0" ]]
else
  exit 0
fi
