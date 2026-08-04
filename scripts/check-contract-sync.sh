#!/usr/bin/env bash
# Thin dual-write / pointer sync checks (public CI).
# Ensures projected rules keep inviolable phrases and point at workflow-contract.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

ok() { echo "PASS  $1"; }
bad() { echo "FAIL  $1 — $2" >&2; fail=$((fail + 1)); }

WF="$ROOT/skills/vibe-coding/references/workflow-contract.md"
WD="$ROOT/skills/vibe-coding/references/wish-delivery.md"
[[ -f "$WF" ]] && ok "workflow-contract" || bad "workflow-contract" "missing"
[[ -f "$WD" ]] && ok "wish-delivery" || bad "wish-delivery" "missing"

grep -q "Deploy P4" "$WF" && ok "wf:deploy-p4" || bad "wf:deploy-p4" "missing Deploy P4"
grep -q "禁止.*自动上生产\|不上生产\|不含 Deploy\|不含.*Deploy" "$WF" \
  && ok "wf:no-auto-prod" || bad "wf:no-auto-prod" "missing no-auto-prod language"
grep -q "关版 ≠ 上线\|关版后.*询问\|另批.*Deploy\|上线须另批" "$WD" \
  && ok "wd:gate-split" || bad "wd:gate-split" "wish-delivery missing 关版≠上线"

FA="$ROOT/skills/dispatch-codex/references/falsify-attestation.md"
[[ -f "$FA" ]] && ok "falsify-attestation" || bad "falsify-attestation" "missing"
grep -q "COMMAND" "$FA" && grep -q "EXIT_CODE" "$FA" \
  && ok "falsify-schema-keys" || bad "falsify-schema-keys" "missing COMMAND/EXIT_CODE"

for rule in sdd-vibe-entry sdd-shape-no-code sdd-deploy-p4 sdd-codex-cli; do
  f="$ROOT/templates/.cursor/rules/${rule}.mdc"
  [[ -f "$f" ]] || { bad "rule:$rule" "missing"; continue; }
  grep -q "workflow-contract\|真源\|plugin skill\|sdd-vibe-coding" "$f" \
    && ok "rule-pointer:$rule" || bad "rule-pointer:$rule" "missing真源指针"
done

grep -q "第一个工具调用" "$ROOT/templates/.cursor/rules/sdd-vibe-entry.mdc" \
  && ok "entry:first-action" || bad "entry:first-action" "missing"
grep -q "Build ≠ Deploy" "$ROOT/templates/.cursor/rules/sdd-deploy-p4.mdc" \
  && ok "deploy:build-ne" || bad "deploy:build-ne" "missing"
grep -q "禁止" "$ROOT/templates/.cursor/rules/sdd-codex-cli.mdc" \
  && ok "codex:ban" || bad "codex:ban" "missing"
grep -q "falsify-attestation\|structured\|COMMAND" \
  "$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh" \
  && ok "require:structured" || bad "require:structured" "script missing structured check"
grep -q "PASSED_SLICES\|flock" \
  "$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh" \
  && ok "wish:idempotent-lock" || bad "wish:idempotent-lock" "missing PASSED_SLICES/flock"
test -f "$ROOT/scripts/hooks/gate-shell.sh" && test -f "$ROOT/scripts/hooks/gate-write.sh" \
  && ok "hooks:gates" || bad "hooks:gates" "missing gate scripts"
test -f "$ROOT/scripts/wish-journey.sh" \
  && ok "wish-journey" || bad "wish-journey" "missing"
test -f "$ROOT/templates/.cursor/hooks.json" \
  && ok "hooks:template" || bad "hooks:template" "missing hooks.json"
grep -q "Claude Code Hooks" "$ROOT/ARCHITECTURE.md" \
  && ok "borrow:hooks" || bad "borrow:hooks" "BORROW table missing Hooks"
test -f "$ROOT/skills/vibe-coding/references/runtime-hooks.md" \
  && ok "runtime-hooks-doc" || bad "runtime-hooks-doc" "missing"

AGENTS="$ROOT/templates/AGENTS.md"
grep -q "dispatch-codex\|codex-dispatch" "$AGENTS" \
  && ok "agents:dispatch-pointer" || bad "agents:dispatch-pointer" "missing"
grep -q "不得.*上生产\|不得上生产\|不上生产" "$AGENTS" \
  && ok "agents:no-auto-prod" || bad "agents:no-auto-prod" "missing"

echo "--- check-contract-sync: fail=$fail ---"
[[ "$fail" -eq 0 ]]
