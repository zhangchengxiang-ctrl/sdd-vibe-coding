#!/usr/bin/env bash
# Public gate suite — no private evals/ required. Safe for CI clones.
# Usage: bash scripts/public-gates.sh
#
# Rot ceiling: skills budget may only shrink (scripts/rot-baseline.json).
# single-definition / orphan-refs: REPORT mode until P1 / P4 flip to strict.
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

report() {
  local name="$1"
  shift
  echo "--- $name (report) ---"
  "$@" || true
  echo "OK $name (report-only)"
}

run "dispatch-gates-selftest" bash skills/dispatch-codex/scripts/selftest-gates.sh
run "hooks-selftest" bash scripts/hooks/selftest-hooks.sh
run "contract-sync" bash scripts/check-contract-sync.sh
run "phase3-plugin-only" env PHASE3_PLUGIN_ONLY=1 bash scripts/phase3-negative-verify.sh
run "rot-meter" bash scripts/rot-meter.sh
report "single-definition" bash scripts/single-definition.sh
report "orphan-refs" bash scripts/orphan-refs.sh

# P1: single-definition strict; P4: orphan-refs strict
run "single-definition-strict" bash scripts/single-definition.sh --strict
run "orphan-refs-strict" bash scripts/orphan-refs.sh --strict

echo "== public-gates summary fail=$fail =="
[[ "$fail" -eq 0 ]]
