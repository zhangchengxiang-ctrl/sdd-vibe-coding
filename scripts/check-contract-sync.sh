#!/usr/bin/env bash
# Asset existence + functional frontmatter checks (public CI).
# Slogan/phrase grep gates removed (rot-mechanisms-v5 P0).
# Does NOT assert Chinese slogans in skill prose.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

ok() { echo "PASS  $1"; }
bad() { echo "FAIL  $1 — $2" >&2; fail=$((fail + 1)); }

# --- core contracts present ---
[[ -f "$ROOT/skills/vibe-coding/references/gates.md" ]] \
  && ok "gates" || bad "gates" "missing"
[[ -f "$ROOT/skills/vibe-coding/references/states.md" ]] \
  && ok "states" || bad "states" "missing"
[[ -f "$ROOT/skills/vibe-coding/references/rails.md" ]] \
  && ok "rails" || bad "rails" "missing"
[[ -f "$ROOT/skills/vibe-coding/references/workflow-contract.md" ]] \
  && ok "workflow-contract-index" || bad "workflow-contract-index" "missing"
[[ -f "$ROOT/skills/dispatch-codex/references/falsify-attestation.md" ]] \
  && ok "falsify-attestation" || bad "falsify-attestation" "missing"

# --- projected rule templates exist ---
for rule in sdd-vibe-entry sdd-shape-no-code sdd-deploy-p4 sdd-codex-cli; do
  f="$ROOT/templates/.cursor/rules/${rule}.mdc"
  [[ -f "$f" ]] && ok "rule:$rule" || bad "rule:$rule" "missing"
done

# --- functional frontmatter: disable auto-invocation on rail skills ---
for _sk in design spec testing deploy debug dispatch-codex; do
  grep -q "disable-model-invocation: true" "$ROOT/skills/$_sk/SKILL.md" \
    && ok "dmi:$_sk" || bad "dmi:$_sk" "missing disable-model-invocation"
done

# --- dispatch / orchestration assets ---
test -f "$ROOT/skills/dispatch-codex/scripts/pack_dispatch_units.py" \
  && ok "pack-dispatch-units" || bad "pack-dispatch-units" "missing"
test -f "$ROOT/skills/dispatch-codex/scripts/schedule_waves.py" \
  && ok "schedule-waves" || bad "schedule-waves" "missing"
test -f "$ROOT/skills/dispatch-codex/scripts/detect_compact.py" \
  && ok "detect-compact" || bad "detect-compact" "missing"
test -f "$ROOT/skills/dispatch-codex/references/dispatch-units.md" \
  && ok "dispatch-units-doc" || bad "dispatch-units-doc" "missing"
test -f "$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh" \
  && ok "require-falsify-script" || bad "require-falsify-script" "missing"
test -f "$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh" \
  && ok "wish-orchestrate-script" || bad "wish-orchestrate-script" "missing"

# --- hooks / journey ---
test -f "$ROOT/scripts/hooks/gate-shell.sh" && test -f "$ROOT/scripts/hooks/gate-write.sh" \
  && ok "hooks:gates" || bad "hooks:gates" "missing gate scripts"
test -f "$ROOT/scripts/wish-journey.sh" \
  && ok "wish-journey" || bad "wish-journey" "missing"
test -f "$ROOT/templates/.cursor/hooks.json" \
  && ok "hooks:template" || bad "hooks:template" "missing hooks.json"
test -f "$ROOT/skills/vibe-coding/references/runtime-hooks.md" \
  && ok "runtime-hooks-doc" || bad "runtime-hooks-doc" "missing"
test -f "$ROOT/templates/AGENTS.md" \
  && ok "agents-template" || bad "agents-template" "missing"

echo "--- check-contract-sync: fail=$fail ---"
[[ "$fail" -eq 0 ]]
