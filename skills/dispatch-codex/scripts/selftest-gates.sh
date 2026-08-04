#!/usr/bin/env bash
# Offline gates for dispatch-codex hard doors (no Codex required).
# Run from plugin root: bash skills/dispatch-codex/scripts/selftest-gates.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSERT="$ROOT/skills/dispatch-codex/scripts/assert_plan_artifacts.py"
REQUIRE="$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  local name="$1" expect="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local st=$?
  set -e
  if [[ "$st" -eq "$expect" ]]; then
    echo "PASS $name (exit $st)"
    pass=$((pass + 1))
  else
    echo "FAIL $name (exit $st expected $expect)" >&2
    fail=$((fail + 1))
  fi
}

# --- assert_plan_artifacts ---
mkdir -p "$TMP/host/docs/specs/empty-spec"
check "plan-missing-files" 1 python3 "$ASSERT" "$TMP/host" empty-spec

SPEC="$TMP/host/docs/specs/ok-spec"
mkdir -p "$SPEC"
for f in VERSION.md contract.md tests.md plan.md run.md; do
  printf '# %s\n\nSubstantial placeholder content for gate test (%s).\n' "$f" "$f" >"$SPEC/$f"
done
check "plan-complete" 0 python3 "$ASSERT" "$TMP/host" ok-spec

# --- require-conductor-falsify verdict ---
LOG="$TMP/logs"
mkdir -p "$LOG"
echo "ran some tests" >"$LOG/run1_falsify.log"
check "falsify-no-verdict" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run1

echo "VERDICT: S1 FAIL" >"$LOG/run2_falsify.log"
check "falsify-verdict-fail" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run2

echo "VERDICT: S1 PASS (conductor re-ran)" >"$LOG/run3_falsify.log"
check "falsify-verdict-pass" 0 bash "$REQUIRE" --log-dir "$LOG" --run-id run3

SKIP_FALSIFY_VERDICT=1 check "falsify-skip-verdict-env" 0 \
  bash "$REQUIRE" --log-dir "$LOG" --run-id run1

# --- auth block present in dispatcher ---
check "auth-block-in-dispatch" 0 \
  grep -q "CLI dispatch authorization" "$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"

echo "--- selftest-gates: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
