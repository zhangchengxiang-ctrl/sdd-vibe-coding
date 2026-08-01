#!/usr/bin/env bash
# Fail if the working tree has business-code changes without Build authorization.
#
# Usage:
#   bash scripts/preflight-rail.sh [--cwd DIR] [--authorized]
#   RAIL_AUTHORIZED=1 bash scripts/preflight-rail.sh
#
# Exit 0: clean / only docs(product|specs|reference|guides|planning|architecture|operations)
#         / authorized
# Exit 1: business paths dirty without --authorized
# Exit 2: usage / not a git repo
set -euo pipefail

CWD="."
AUTHORIZED="${RAIL_AUTHORIZED:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --authorized) AUTHORIZED=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "usage: $0 [--cwd DIR] [--authorized]" >&2
      exit 2
      ;;
  esac
done

CWD="$(cd "$CWD" && pwd)"
cd "$CWD"

if [[ "$AUTHORIZED" == "1" ]]; then
  echo "preflight-rail: AUTHORIZED=1 — skip dirty check"
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "preflight-rail: not a git repo: $CWD" >&2
  exit 2
fi

# Paths that are OK without Build approval (docs / product / specs / agent meta)
allow_re='^(docs/|.*\.md$|\.cursor/|AGENTS\.md$|CLAUDE\.md$|README|LICENSE|Makefile$|package\.json$|pyproject\.toml$|\.gitignore$|templates/)'

mapfile -t dirty < <(git status --porcelain -u --no-renames | awk '{print $NF}')
biz=()
for p in "${dirty[@]:-}"; do
  [[ -z "$p" ]] && continue
  if [[ "$p" =~ $allow_re ]]; then
    continue
  fi
  # still allow docs/** even if pattern missed
  case "$p" in
    docs/*|*.md) continue ;;
  esac
  biz+=("$p")
done

if ((${#biz[@]} == 0)); then
  echo "preflight-rail: ok (no unauthorized business dirty paths)"
  exit 0
fi

echo "preflight-rail: FAIL — business paths dirty without Build authorization:" >&2
printf '  %s\n' "${biz[@]}" >&2
echo "preflight-rail: Shape/discuss may only write docs/product (etc). Pass --authorized after「开始做/批准 Build」." >&2
exit 1
