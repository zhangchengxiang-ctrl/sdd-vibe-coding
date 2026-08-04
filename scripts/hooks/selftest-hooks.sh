#!/usr/bin/env bash
# Offline selftest for runtime hooks + wish-journey (no Cursor required).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE_SHELL="$ROOT/scripts/hooks/gate-shell.sh"
GATE_WRITE="$ROOT/scripts/hooks/gate-write.sh"
AUTH="$ROOT/scripts/hooks/authorize.sh"
JOURNEY="$ROOT/scripts/wish-journey.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  local name="$1" expect="$2"
  shift 2
  set +e
  out="$("$@" 2>/dev/null)"
  st=$?
  set -e
  if [[ "$st" -eq "$expect" ]]; then
    echo "PASS $name (exit $st)"
    pass=$((pass + 1))
  else
    echo "FAIL $name (exit $st expected $expect) out=$out" >&2
    fail=$((fail + 1))
  fi
}

check_perm() {
  local name="$1" expect_perm="$2"
  shift 2
  set +e
  out="$("$@" 2>/dev/null)"
  st=$?
  set -e
  if [[ "$st" -eq 0 ]] && echo "$out" | grep -q "\"permission\": \"$expect_perm\"" || echo "$out" | grep -q "\"permission\":\"$expect_perm\""; then
    echo "PASS $name (perm=$expect_perm)"
    pass=$((pass + 1))
  else
    echo "FAIL $name (want perm=$expect_perm got=$out)" >&2
    fail=$((fail + 1))
  fi
}

HOST="$TMP/host"
mkdir -p "$HOST/docs/product" "$HOST/src"
printf '# host\n' >"$HOST/AGENTS.md"

# --- shell gate: allow harmless ---
check_perm "shell-allow-ls" allow \
  bash -c "echo '{\"command\":\"ls -la\",\"cwd\":\"$HOST\"}' | bash '$GATE_SHELL'"

# --- shell gate: deny deploy without auth ---
check_perm "shell-deny-vercel-prod" deny \
  bash -c "echo '{\"command\":\"vercel --prod\",\"cwd\":\"$HOST\"}' | bash '$GATE_SHELL'"

# --- authorize deploy then allow ---
bash "$AUTH" --cwd "$HOST" --kind deploy-p4 --note test >/dev/null
check_perm "shell-allow-vercel-after-p4" allow \
  bash -c "echo '{\"command\":\"vercel --prod\",\"cwd\":\"$HOST\"}' | bash '$GATE_SHELL'"

# --- write gate: deny src without auth ---
bash "$AUTH" --cwd "$HOST" --kind deploy-p4 --revoke >/dev/null 2>&1 || true
rm -f "$HOST/.sdd/authorize.build"
check_perm "write-deny-src" deny \
  bash -c "echo '{\"tool_name\":\"Write\",\"cwd\":\"$HOST\",\"tool_input\":{\"path\":\"$HOST/src/app.ts\"}}' | bash '$GATE_WRITE'"

# --- write gate: allow docs/product ---
check_perm "write-allow-product" allow \
  bash -c "echo '{\"tool_name\":\"Write\",\"cwd\":\"$HOST\",\"tool_input\":{\"path\":\"$HOST/docs/product/note.md\"}}' | bash '$GATE_WRITE'"

# --- write gate: allow after build auth ---
bash "$AUTH" --cwd "$HOST" --kind build >/dev/null
check_perm "write-allow-src-after-build" allow \
  bash -c "echo '{\"tool_name\":\"Write\",\"cwd\":\"$HOST\",\"tool_input\":{\"path\":\"$HOST/src/app.ts\"}}' | bash '$GATE_WRITE'"

# --- journey transitions ---
check "journey-set-design" 0 bash "$JOURNEY" --cwd "$HOST" --spec demo --set design-ready
check "journey-bad-jump" 1 bash "$JOURNEY" --cwd "$HOST" --spec demo --transition acceptance-passed
check "journey-to-planning" 0 bash "$JOURNEY" --cwd "$HOST" --spec demo --transition planning
check "journey-to-building" 0 bash "$JOURNEY" --cwd "$HOST" --spec demo --transition building
check "journey-assert-build" 0 bash "$JOURNEY" --cwd "$HOST" --spec demo --assert build
check "journey-assert-deploy-fail" 1 bash "$JOURNEY" --cwd "$HOST" --spec demo --assert deploy

echo "--- hooks-selftest: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
