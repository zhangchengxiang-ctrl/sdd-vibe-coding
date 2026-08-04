#!/usr/bin/env bash
# Create / revoke SDD runtime authorization markers under <host>/.sdd/
#
# Usage:
#   bash scripts/hooks/authorize.sh --cwd HOST --kind build|deploy-p4 [--revoke] [--note TEXT]
set -euo pipefail
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HOOKS_DIR/lib.sh"

CWD="."
KIND=""
REVOKE=0
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --kind) KIND="${2:-}"; shift 2 ;;
    --revoke) REVOKE=1; shift ;;
    --note) NOTE="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$KIND" ]] || { echo "authorize: --kind build|deploy-p4 required" >&2; exit 2; }
ROOT="$(sdd_find_root "$CWD")"
mkdir -p "$ROOT/.sdd"

case "$KIND" in
  build) FILE="$ROOT/.sdd/authorize.build" ;;
  deploy-p4|deploy) FILE="$ROOT/.sdd/authorize.deploy-p4" ;;
  *) echo "authorize: unknown kind $KIND" >&2; exit 2 ;;
esac

if [[ "$REVOKE" == "1" ]]; then
  rm -f "$FILE"
  echo "authorize: revoked $FILE"
  exit 0
fi

{
  echo "authorized_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "kind=$KIND"
  [[ -n "$NOTE" ]] && echo "note=$NOTE"
} >"$FILE"
echo "authorize: wrote $FILE"
echo "authorize: remember — markers are session evidence, not a substitute for human Deploy P4 intent."
