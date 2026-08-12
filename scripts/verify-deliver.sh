#!/usr/bin/env bash
# Verify / Deploy close gate: check_spec --closing (positive evidence, no stamp).
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

echo "== verify-deliver: check_spec --closing =="
python3 "$ROOT/skills/spec/scripts/check_spec.py" \
  "$HOST" "$SPEC" --skip-agents --closing

echo "verify-deliver: ok"
