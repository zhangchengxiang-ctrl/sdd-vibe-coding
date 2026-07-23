#!/usr/bin/env bash
# Resolve the host repository and run deterministic SDD document validation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${1:-}" && -f "$1/AGENTS.md" ]]; then
  ROOT="$(cd "$1" && pwd)"
elif [[ -f "$PWD/AGENTS.md" ]]; then
  ROOT="$PWD"
elif [[ -f "$SCRIPT_DIR/../AGENTS.md" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  echo "ERROR: run from a host repo with AGENTS.md or pass its path" >&2
  exit 1
fi

exec python3 "$SCRIPT_DIR/check-docs.py" "$ROOT"
