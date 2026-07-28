#!/usr/bin/env bash
# Spec static gates (plan skeleton, tests, architecture section, run honesty).
# Usage: check_spec.sh <host-root> [spec-id|path] [--all] [--agents-only]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${1:-}" ]]; then
  echo "usage: check_spec.sh <host-root> [spec-id|path] [--all] [--agents-only]" >&2
  exit 2
fi
HOST="$1"
shift
exec python3 "$SCRIPT_DIR/check_spec.py" "$HOST" "$@"
