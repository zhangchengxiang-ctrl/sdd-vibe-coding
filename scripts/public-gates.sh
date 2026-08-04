#!/usr/bin/env bash
# Public gate suite — no private evals/ required. Safe for CI clones.
# Usage: bash scripts/public-gates.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== public-gates =="
fail=0

run() {
  local name="$1"
  shift
  echo "--- $name ---"
  if "$@"; then
    echo "OK $name"
  else
    echo "FAIL $name" >&2
    fail=$((fail + 1))
  fi
}

run "dispatch-gates-selftest" bash skills/dispatch-codex/scripts/selftest-gates.sh
run "hooks-selftest" bash scripts/hooks/selftest-hooks.sh
run "contract-sync" bash scripts/check-contract-sync.sh
run "phase3-plugin-only" env PHASE3_PLUGIN_ONLY=1 bash scripts/phase3-negative-verify.sh

echo "== public-gates summary fail=$fail =="
[[ "$fail" -eq 0 ]]
