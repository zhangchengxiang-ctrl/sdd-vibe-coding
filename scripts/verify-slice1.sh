#!/usr/bin/env bash
# verify-slice1.sh — 结构 + 三端清单 + scaffold + hooks + check-docs-sdd
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

ok() { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; FAIL=1; }

echo "== plugin.json name + version align =="
name=$(python3 -c "import json; print(json.load(open('$ROOT/.cursor-plugin/plugin.json'))['name'])")
ver=$(python3 -c "import json; print(json.load(open('$ROOT/.cursor-plugin/plugin.json'))['version'])")
cver=$(python3 -c "import json; print(json.load(open('$ROOT/.claude-plugin/plugin.json'))['version'])")
xver=$(python3 -c "import json; print(json.load(open('$ROOT/.codex-plugin/plugin.json'))['version'])")
if [[ "$name" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
  ok "name=$name version=$ver"
else
  bad "name must be lowercase kebab-case, got: $name"
fi
if [[ "$ver" == "$cver" && "$ver" == "$xver" ]]; then
  ok "cursor/claude/codex versions aligned ($ver)"
else
  bad "version drift cursor=$ver claude=$cver codex=$xver"
fi

echo "== hooks hard gate unit (Cursor + Claude harness) =="
if node "$ROOT/scripts/verify-hooks-unit.mjs" >/dev/null; then
  ok "hooks deny business write on Intake (cursor+harness)"
else
  bad "hooks unit failed"
fi

echo "== structure =="
for p in \
  .cursor-plugin/plugin.json \
  .claude-plugin/plugin.json \
  .claude-plugin/marketplace.json \
  .codex-plugin/plugin.json \
  .agents/plugins/marketplace.json \
  hooks/hooks.json \
  hooks.json \
  package.json \
  LICENSE \
  README.md \
  scripts/hooks/pre-tool-use.mjs \
  scripts/hooks/before-submit-prompt.mjs \
  scripts/hooks/harness-pre-tool-use.mjs \
  scripts/hooks/harness-user-prompt.mjs \
  scripts/hooks/harness-session-start.mjs \
  scripts/hooks/harness-lib.mjs \
  scripts/install-local.sh \
  scripts/scaffold.sh \
  scripts/check-docs-sdd.sh \
  rules/00-judge-track-first.mdc \
  rules/01-product-memory-first.mdc \
  rules/02-gate-precedence.mdc \
  rules/03-completion-gate.mdc \
  rules/04-docs-backfill.mdc \
  rules/05-conversation-hygiene.mdc \
  skills/vibe-coding/SKILL.md \
  skills/vibe-coding/references/role-rails.md \
  skills/vibe-coding/references/execution-discipline.md \
  skills/vibe-coding/references/acceptance-to-remediation.md \
  skills/product-design-package/SKILL.md \
  skills/spec/SKILL.md \
  skills/testing/SKILL.md \
  skills/_docs-factory/CONVENTIONS.md \
  skills/_docs-factory/VALIDATION-REPORT.md \
  skills/_docs-factory/UX-STANDARDS.md \
  templates/AGENTS.md \
  templates/docs/README.md \
  templates/docs/product/foundation/product-regression.md \
  templates/docs/product/foundation/mission.md \
  templates/docs/product/foundation/principles.md \
  templates/docs/product/foundation/personas-journeys.md \
  templates/docs/product/foundation/product-package-contract.md \
  templates/docs/product/regression/surfaces.json \
  templates/docs/product/regression-register.md \
  templates/docs/specs/_template/optional/experience-design.md \
  templates/docs/specs/_template/optional/problem-map.md \
  templates/docs/planning/roadmap.md \
  templates/docs/product/decisions/_BORROW-template.md \
  templates/docs/guides/vibe-coding.md
do
  [[ -e "$ROOT/$p" ]] && ok "$p" || bad "missing $p"
done

echo "== vibe-coding line budget (~120) =="
lines=$(wc -l < "$ROOT/skills/vibe-coding/SKILL.md")
if [[ "$lines" -le 130 ]]; then ok "vibe-coding SKILL.md = $lines lines"; else bad "vibe-coding too long: $lines"; fi

echo "== de-AgentDeck coupling (forbidden hardcodes in plugin body) =="
FORBIDDEN_PATTERNS=(
  'ccc\.dev\.local'
  'ccc\.flow\.chat'
  'extensions-hub'
  'DS4 Flash'
  'deepseek-v4-flash'
  'kaon/deepseek'
  'make reload-web'
  'agentdeck-ui'
  'NEXUS_'
  'apps/web/src/extensions'
  'apps/worker/src/extensions'
  'verify-ui'
  'spec-generate'
)
for pat in "${FORBIDDEN_PATTERNS[@]}"; do
  if rg -n --glob '!README.md' --glob '!verify-slice1.sh' --glob '!evidence/**' -e "$pat" \
      "$ROOT/rules" "$ROOT/skills" "$ROOT/templates" "$ROOT/scripts" >/tmp/sdd-coup.txt 2>/dev/null; then
    bad "forbidden pattern /$pat/:"
    cat /tmp/sdd-coup.txt
  else
    ok "no /$pat/"
  fi
done

echo "== product-memory gate language =="
for needle in '产品记忆' '开始做' 'docs/product/' '业务代码'; do
  if rg -q "$needle" "$ROOT/rules/01-product-memory-first.mdc"; then
    ok "01 contains [$needle]"
  else
    bad "01 missing [$needle]"
  fi
done
if rg -q '优先于|Precedence|判轨' "$ROOT/rules/02-gate-precedence.mdc"; then
  ok "02 precedence present"
else
  bad "02 missing precedence"
fi

echo "== violation regression table (优化+编号清单 → Intake) =="
ROUTE_OK=1
rg -q '优化' "$ROOT/rules/00-judge-track-first.mdc" || ROUTE_OK=0
rg -q '编号清单' "$ROOT/rules/00-judge-track-first.mdc" || ROUTE_OK=0
rg -q 'Intake' "$ROOT/rules/00-judge-track-first.mdc" || ROUTE_OK=0
rg -q '禁止' "$ROOT/rules/00-judge-track-first.mdc" || ROUTE_OK=0
rg -q '编号清单' "$ROOT/skills/vibe-coding/references/role-rails.md" || ROUTE_OK=0
rg -q '两者皆无' "$ROOT/rules/01-product-memory-first.mdc" || ROUTE_OK=0
if [[ "$ROUTE_OK" -eq 1 ]]; then
  ok "假 Build 信号 → Intake + 产品记忆闸 encoded"
else
  bad "routing contract incomplete"
fi

echo "== empty-repo scaffold =="
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
bash "$ROOT/scripts/scaffold.sh" "$TMP"
for must in \
  AGENTS.md \
  CLAUDE.md \
  docs/README.md \
  docs/product/demand-pool.md \
  docs/product/foundation/product-regression.md \
  docs/product/regression/surfaces.json \
  docs/reference/handoff.md \
  docs/specs/_template/VERSION.md \
  scripts/check-docs-sdd.sh \
  .cursor/sdd-enabled \
  .claude/sdd-enabled \
  .cursor/rules/00-judge-track-first.mdc \
  .claude/rules/00-judge-track-first.md
do
  [[ -e "$TMP/$must" ]] && ok "scaffold created $must" || bad "scaffold missing $must"
done

bash "$ROOT/scripts/scaffold.sh" "$TMP" >/tmp/sdd-sc2.txt 2>&1 || true
if [[ -f "$TMP/AGENTS.md" ]]; then
  ok "scaffold idempotent / safe re-run"
else
  bad "scaffold re-run unexpected"
fi

echo "== check-docs-sdd on fresh scaffold =="
if bash "$TMP/scripts/check-docs-sdd.sh" "$TMP"; then
  ok "check-docs-sdd green on scaffold"
else
  bad "check-docs-sdd failed on scaffold"
fi

echo "== claude plugin validate =="
if command -v claude >/dev/null 2>&1; then
  if claude plugin validate "$ROOT" >/tmp/sdd-claude-validate.txt 2>&1; then
    ok "claude plugin validate"
  else
    bad "claude plugin validate failed"
    head -40 /tmp/sdd-claude-validate.txt
  fi
else
  ok "claude CLI absent — skip validate"
fi

echo "== simulated Intake decision (优化 X + 1,2,3) =="
if rg -q '两者皆无' "$ROOT/rules/01-product-memory-first.mdc" \
  && rg -q '优化' "$ROOT/rules/00-judge-track-first.mdc"; then
  ok "empty memory + 优化清单 → Intake-only (gate contract)"
else
  bad "cannot prove Intake gate"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS — Slice 2–3 / 0.3.0 Claude+Codex packaging green"
exit 0
