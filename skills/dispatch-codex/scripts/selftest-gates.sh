#!/usr/bin/env bash
# Offline gates for dispatch-codex hard doors (no Codex required).
# Run from plugin root: bash skills/dispatch-codex/scripts/selftest-gates.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSERT="$ROOT/skills/dispatch-codex/scripts/assert_plan_artifacts.py"
REQUIRE="$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh"
RECORD="$ROOT/skills/dispatch-codex/scripts/record-conductor-falsify.sh"
WISH="$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh"
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

# --- require-conductor-falsify: unstructured / structured ---
LOG="$TMP/logs"
mkdir -p "$LOG"
echo "ran some tests" >"$LOG/run1_falsify.log"
check "falsify-no-verdict" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run1

echo "VERDICT: S1 FAIL" >"$LOG/run2_falsify.log"
check "falsify-verdict-fail-unstructured" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run2

# Verdict PASS alone is no longer enough
echo "VERDICT: S1 PASS (conductor re-ran)" >"$LOG/run3_falsify.log"
check "falsify-verdict-pass-unstructured" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run3

# Structured PASS
cat >"$LOG/run4_falsify.log" <<'EOF'
COMMAND: echo probe
EXIT_CODE: 0
SLICE: S1
RUN_ID: run4
VERDICT: S1 PASS
EOF
check "falsify-structured-pass" 0 bash "$REQUIRE" --log-dir "$LOG" --run-id run4

# PASS with non-zero EXIT_CODE
cat >"$LOG/run5_falsify.log" <<'EOF'
COMMAND: false
EXIT_CODE: 1
VERDICT: S1 PASS
EOF
check "falsify-pass-nonzero-exit" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run5

# ARTIFACT without hash
cat >"$LOG/run6_falsify.log" <<'EOF'
COMMAND: echo x
EXIT_CODE: 0
ARTIFACT: /tmp/nope
VERDICT: S1 PASS
EOF
check "falsify-artifact-no-hash" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run6

SKIP_FALSIFY_VERDICT=1 check "falsify-skip-verdict-env" 0 \
  bash "$REQUIRE" --log-dir "$LOG" --run-id run1

SKIP_STRUCTURED_FALSIFY=1 check "falsify-skip-structured-env" 0 \
  bash "$REQUIRE" --log-dir "$LOG" --run-id run3

# --- record-conductor-falsify ---
check "record-falsify-success" 0 \
  bash "$RECORD" --log-dir "$LOG" --run-id rec1 --slice S1 -- true
check "require-after-record" 0 bash "$REQUIRE" --log-dir "$LOG" --run-id rec1
check "record-falsify-fail-cmd" 1 \
  bash "$RECORD" --log-dir "$LOG" --run-id rec2 --slice S1 -- false
check "require-after-record-fail" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id rec2

# --- wish-orchestrate: status + flock smoke (no codex) ---
HOST="$TMP/wishhost"
mkdir -p "$HOST/docs/specs/w1"
cat >"$HOST/docs/specs/w1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | Web：a | T-001 | src/a.ts | | |
| S2 | Web：b | T-002 | src/b.ts | S1 | |
EOF
for f in VERSION.md contract.md tests.md run.md; do
  printf '# %s\n\nenough content for placeholder gates.\n' "$f" >"$HOST/docs/specs/w1/$f"
done
check "wish-status" 0 bash "$WISH" --cwd "$HOST" --spec w1 --status
check "wish-list" 0 bash "$WISH" --cwd "$HOST" --spec w1 --list
check "wish-pack-only" 0 bash "$WISH" --cwd "$HOST" --spec w1 --pack-only --slice S1

# Idempotency: mark S1 passed in state, pack-only still ok; dry-run skips passed
LOGW="$HOST/.codex-dispatch-logs"
mkdir -p "$LOGW"
cat >"$LOGW/wish-state-w1.env" <<'EOF'
AWAITING_FALSIFY=0
LAST_RUN_ID=
LAST_SLICE=
PASSED_SLICES='S1'
CORRELATION_ID=w1-test
SPEC_ID=w1
EOF
check "wish-dry-skip-passed" 0 bash "$WISH" --cwd "$HOST" --spec w1 --dry-run --slice S1

# --- auth block present in dispatcher ---
check "auth-block-in-dispatch" 0 \
  grep -q "CLI dispatch authorization" "$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"

# --- attestation doc exists ---
check "falsify-attestation-doc" 0 \
  test -f "$ROOT/skills/dispatch-codex/references/falsify-attestation.md"

echo "--- selftest-gates: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
