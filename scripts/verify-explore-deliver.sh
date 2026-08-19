#!/usr/bin/env bash
# Verify Explore/Deliver optimization: static assets + deliver gates + agent substance.
# Usage: bash scripts/verify-explore-deliver.sh
# Skips cursor-agent probes if cursor-agent not on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0

ok() { PASS=$((PASS + 1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL  $1 — $2" >&2; }
skip() { SKIP=$((SKIP + 1)); echo "SKIP  $1 — $2"; }

run_step() {
  local label="$1"
  shift
  set +e
  "$@" >/tmp/verify-ed-out.txt 2>/tmp/verify-ed-err.txt
  local st=$?
  set -e
  if [[ "$st" -eq 0 ]]; then
    ok "$label"
  else
    bad "$label" "exit=$st; $(tail -3 /tmp/verify-ed-err.txt | tr '\n' ' ')"
  fi
}

echo "== verify-explore-deliver =="
echo "ROOT=$ROOT"

# --- Static: new contract files ---
for f in \
  skills/vibe-coding/references/explore-deliver.md \
  skills/spec/references/infra-mechanism-brief.md; do
  if [[ -f "$ROOT/$f" ]]; then ok "file:$f"; else bad "file:$f" "missing"; fi
done

grep -q "Explore / Deliver" "$ROOT/skills/vibe-coding/SKILL.md" \
  && ok "skill:vibe-coding-explore-deliver" \
  || bad "skill:vibe-coding-explore-deliver" "SKILL.md missing Explore/Deliver"

grep -q "默认：Explore" "$ROOT/skills/design/SKILL.md" \
  && ok "skill:design-explore-default" \
  || bad "skill:design-explore-default" "design/SKILL.md missing Explore default"

grep -q "Explore vs Deliver" "$ROOT/skills/vibe-coding/references/gates.md" \
  && ok "gates:explore-vs-deliver" \
  || bad "gates:explore-vs-deliver" "gates.md missing section"

grep -q "文档对齐冒充设计" "$ROOT/skills/design/references/scheme-antipatterns.md" \
  && ok "antipattern:doc-align" \
  || bad "antipattern:doc-align" "scheme-antipatterns #7 not updated"

# --- Deliver path (offline, no LLM) ---
run_step "selftest-ship" bash skills/dispatch-codex/scripts/selftest-ship.sh
run_step "phase3-negative-plugin" env PHASE3_PLUGIN_ONLY=1 bash scripts/phase3-negative-verify.sh

# --- Load-tier probes (subset + full if time) ---
if command -v cursor-agent >/dev/null 2>&1; then
  run_step "eval-skill-load-key" python3 scripts/eval-skill-load-cursor.py \
    --case K-SOFT-ENTRY \
    --case E-EXPLORE-DEFAULT-NO-CARD \
    --case I-INFRA-MECHANISM-ROUTE-SPEC \
    --case S-UI-ACL-JUDGMENT
  run_step "eval-explore-substance" python3 scripts/eval-explore-substance.py
else
  skip "cursor-agent-probes" "cursor-agent not on PATH"
fi

echo "--------"
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
