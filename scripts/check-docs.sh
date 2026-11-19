#!/usr/bin/env bash
# check-docs.sh — read-only consistency check of a host's SDD docs tree.
#
# Checks (all against the host's own docs/README.md, which is the placement standard it adopted
# from templates/docs/README.md):
#   1. placement   every top-level dir under the docs root is explained in README's
#                  「这份文档该放哪」 section (host extensions must be declared)      -> WARN
#   2. metadata    docs under iterations/, operations/requests|runbooks, reports/
#                  carry front matter: title, type, status, owner, updated            -> WARN
#   3. links       relative markdown links that point at nothing                      -> count;
#                  with --max-broken N the run FAILS when the count exceeds N (ratchet)
#
# Usage: bash scripts/check-docs.sh <host-root> [--max-broken N]
# Exit:  0 ok (warnings allowed) · 1 broken-link ceiling exceeded · 2 usage
set -euo pipefail

HOST=""; MAX_BROKEN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-broken) MAX_BROKEN="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "check-docs: unknown option $1" >&2; exit 2 ;;
    *) HOST="$1"; shift ;;
  esac
done
[[ -n "$HOST" && -d "$HOST" ]] || { echo "usage: check-docs.sh <host-root> [--max-broken N]" >&2; exit 2; }
HOST="$(cd "$HOST" && pwd)"

docs_root="docs"
if [[ -f "$HOST/AGENTS.md" ]]; then
  found="$(sed -n 's/^[[:space:]]*-[[:space:]]*SDD docs root:[[:space:]]*`\{0,1\}\([^`[:space:]]\{1,\}\)`\{0,1\}.*/\1/p' "$HOST/AGENTS.md" | head -1 || true)"
  [[ -n "$found" ]] && docs_root="${found%/}"
fi
DOCS="$HOST/$docs_root"
[[ -d "$DOCS" ]] || { echo "check-docs: docs root not found: $DOCS" >&2; exit 2; }

python3 - "$DOCS" "${MAX_BROKEN:-}" <<'PY'
import os, re, sys
from pathlib import Path
from urllib.parse import unquote

docs = Path(sys.argv[1]); max_broken = int(sys.argv[2]) if sys.argv[2] else None
warns = 0

# ---- 1. placement coverage ------------------------------------------------------------
readme = docs / "README.md"
text = readme.read_text(encoding="utf-8") if readme.is_file() else ""
m = re.search(r"^###?\s*这份文档该放哪.*?(?=^#{2,3}\s|\Z)", text, re.S | re.M)
scope = m.group(0) if m else text
if not text:
    print(f"WARN  {docs.name}/README.md missing — nothing declares where documents go"); warns += 1
elif not m:
    print("WARN  README has no 「这份文档该放哪」 section; checking directory names against the whole README"); warns += 1
for d in sorted(p for p in docs.iterdir() if p.is_dir() and not p.name.startswith((".", "_"))):
    if not re.search(rf"(?<![\w-]){re.escape(d.name)}/", scope):
        print(f"WARN  placement: top-level dir `{d.name}/` is not explained in the placement table"); warns += 1

# ---- 2. metadata on typed docs ---------------------------------------------------------
KEYS = ("title", "type", "status", "owner", "updated")
typed = []
for rel in ("iterations", "operations/requests", "operations/runbooks", "reports"):
    base = docs / rel
    if base.is_dir():
        typed += [p for p in base.rglob("*.md")
                  if not p.name.startswith("_template") and "_template" not in p.parts]
missing = []
for p in typed:
    head = p.read_text(encoding="utf-8", errors="replace")
    fm = re.match(r"^---\n(.*?)\n---\n", head, re.S)
    have = set(re.findall(r"^(\w+):", fm.group(1), re.M)) if fm else set()
    if not set(KEYS) <= have:
        missing.append(p)
if missing:
    warns += 1
    print(f"WARN  metadata: {len(missing)}/{len(typed)} typed doc(s) lack front matter {KEYS}; first: "
          + ", ".join(str(p.relative_to(docs)) for p in missing[:5]))

# ---- 3. dead relative links ------------------------------------------------------------
LINK = re.compile(r"\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
def is_ext(t): return re.match(r"^([A-Za-z][A-Za-z0-9+.-]*:|#|/)", t) is not None
broken = 0
for p in docs.rglob("*.md"):
    body = re.sub(r"```.*?```", "", p.read_text(encoding="utf-8", errors="replace"), flags=re.S)
    for t in LINK.findall(body):
        if is_ext(t):
            continue
        path = unquote(re.split(r"[#?]", t, maxsplit=1)[0])
        if path and not os.path.exists(os.path.normpath(os.path.join(p.parent, path))):
            broken += 1
print(f"check-docs: warnings={warns} broken_links={broken}"
      + (f" ceiling={max_broken}" if max_broken is not None else ""))
if max_broken is not None and broken > max_broken:
    print(f"ERROR broken links {broken} > ceiling {max_broken}", file=sys.stderr); sys.exit(1)
PY
