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
corpus = []   # (resolved path, text) — the path is needed to exclude a candidate's own text
# skills/**/scripts/* belongs in the corpus too: one skill selftest invokes another by
# full path, and leaving skill scripts out made that invocation invisible — the check
# would have called a wired script unwired. Deliberately no filename here: a comment
# naming the file with its extension would satisfy this very check, which is how the
# first draft of this comment hid the bug it was describing.
for f in list(Path("skills").rglob("*.md")) + list(Path("skills").glob("*/scripts/*")) \
        + list(Path("scripts").rglob("*")) \
        + [Path("Makefile"), Path("ARCHITECTURE.md"), Path("README.md")]:
    if f.is_file() and not skip_path(str(f)):
        try:
            corpus.append((f.resolve(), f.read_text(encoding="utf-8", errors="ignore")))
        except OSError:
            pass


def is_script(f: Path) -> bool:
    """Top-level scripts/ also holds fixtures and baselines; only scan the runnable ones."""
    if f.suffix in {".sh", ".py"}:
        return True
    try:
        with f.open("rb") as fh:
            return fh.read(2) == b"#!"
    except OSError:
        return False


# skills/*/scripts/* plus top-level scripts/ — a gate that lives in the blind spot of
# the unwired check can lie about coverage forever, which is the thing this check exists
# to prevent. Self-exclusion matters: a script names itself in its own usage text, so
# counting its own body as a reference makes the check vacuous (measured: 0 vs 2 hits).
candidates = sorted(Path("skills").glob("*/scripts/*")) \
    + sorted(f for f in Path("scripts").rglob("*") if f.is_file() and is_script(f))
for f in candidates:
    s = str(f).replace("\\", "/")
    if not f.is_file() or skip_path(s) or f.suffix == ".pyc":
        continue
    # Match the file NAME, not the stem. Attacked and confirmed: a script named rot.sh
    # passed on the "rot" inside rot-meter and `make rot`, and any short stem is a
    # substring of something. A real invocation always writes the extension.
    # (Still fooled by a bare mention in a comment — mention-vs-use is not solved here.)
    name, own = f.name, f.resolve()
    if not any(name in text for path, text in corpus if path != own):
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
