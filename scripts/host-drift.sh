#!/usr/bin/env bash
# Optional host-repo drift checks (manual; NOT in public-gates).
# Usage: bash scripts/host-drift.sh
# Env: PHASE3_AGENTDECK / PHASE3_BI / PHASE3_DATASAGE
set -euo pipefail

PASS=0
FAIL=0
SKIP=0

ok() { PASS=$((PASS + 1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL  $1 — $2" >&2; }
skip() { SKIP=$((SKIP + 1)); echo "SKIP  $1 — $2"; }

AGENTDECK="${PHASE3_AGENTDECK:-/home/zcx/code/agentdeck}"
BI="${PHASE3_BI:-/home/zcx/code/bi-kaonai-dashboard}"
DATASAGE="${PHASE3_DATASAGE:-/home/zcx/code/data-sage}"

echo "== host-drift (manual) =="

if [[ -d "$BI" ]]; then
  if grep -q 'vibe-coding' "$BI/AGENTS.md" \
    && grep -Eq '@AGENTS\.md|AGENTS\.md' "$BI/CLAUDE.md" \
    && ! grep -q 'StarRocks' "$BI/CLAUDE.md"; then
    ok "host:bi-entry"
  else
    bad "host:bi-entry" "CLAUDE/AGENTS not cleaned or missing vibe-coding"
  fi
  if grep -q 'Build ≠ Deploy' "$BI/AGENTS.md"; then
    ok "host:bi-deploy-gate"
  else
    bad "host:bi-deploy-gate" "missing Build≠Deploy in AGENTS"
  fi
else
  skip "host:bi" "not found"
fi

if [[ -d "$DATASAGE" ]]; then
  if grep -q 'vibe-coding' "$DATASAGE/AGENTS.md" && grep -q '优先' "$DATASAGE/AGENTS.md"; then
    ok "host:datasage-agents-pointer"
  else
    bad "host:datasage-agents-pointer" "missing plugin priority"
  fi
  if [[ -d "$DATASAGE/.agents/skills/datasage-pytest" && ! -e "$DATASAGE/.agents/skills/testing" ]]; then
    ok "host:datasage-pytest-rename"
  else
    bad "host:datasage-pytest-rename" "testing not renamed to datasage-pytest"
  fi
  if grep -Eq '已降权|路由降权' "$DATASAGE/.agents/skills/spec-generate/SKILL.md" 2>/dev/null; then
    ok "host:datasage-spec-generate-deprecated"
  else
    bad "host:datasage-spec-generate-deprecated" "no deprecation marker"
  fi
  if grep -Eq 'archived|归档' "$DATASAGE/docs/guides/factory-workflow.md" 2>/dev/null; then
    ok "host:datasage-factory-archived"
  else
    bad "host:datasage-factory-archived" "factory-workflow not archived"
  fi
else
  skip "host:datasage" "not found"
fi

if [[ -d "$AGENTDECK" ]]; then
  if grep -q '禁止' "$AGENTDECK/.cursor/rules/01-first-principles.mdc" 2>/dev/null \
    && grep -q 'spec-generate' "$AGENTDECK/.cursor/rules/01-first-principles.mdc" 2>/dev/null; then
    ok "host:agentdeck-no-spec-generate"
  else
    bad "host:agentdeck-no-spec-generate" "01-first-principles not updated"
  fi
  if grep -q '58-docs-backfill' "$AGENTDECK/AGENTS.md" 2>/dev/null; then
    bad "host:agentdeck-ghost-58" "AGENTS still cites 58-docs-backfill"
  else
    ok "host:agentdeck-ghost-58-cleared"
  fi
  if grep -q '适配器' "$AGENTDECK/.cursor/skills/deploy/SKILL.md" 2>/dev/null \
    && grep -q '适配器' "$AGENTDECK/.cursor/skills/verify-ui/SKILL.md" 2>/dev/null; then
    ok "host:agentdeck-adapters"
  else
    bad "host:agentdeck-adapters" "deploy/verify-ui missing 适配器"
  fi
else
  skip "host:agentdeck" "not found"
fi

echo "--- host-drift: PASS=$PASS FAIL=$FAIL SKIP=$SKIP ---"
[[ "$FAIL" -eq 0 ]]
