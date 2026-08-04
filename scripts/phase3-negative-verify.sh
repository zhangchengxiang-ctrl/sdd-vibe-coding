#!/usr/bin/env bash
# Phase 3 negative acceptance — machine-checkable gates after Phase 0–2.
# Usage: bash scripts/phase3-negative-verify.sh
# Optional: PHASE3_AGENTDECK / PHASE3_BI / PHASE3_DATASAGE
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PHASE3_ROOT="$ROOT"

PASS=0
FAIL=0
SKIP=0
RESULTS=()

ok() { PASS=$((PASS + 1)); RESULTS+=("PASS  $1"); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); RESULTS+=("FAIL  $1 — $2"); echo "FAIL  $1 — $2" >&2; }
skip() { SKIP=$((SKIP + 1)); RESULTS+=("SKIP  $1 — $2"); echo "SKIP  $1 — $2"; }

expect_exit() {
  local want="$1" label="$2"
  shift 2
  set +e
  "$@" >/tmp/phase3-out.txt 2>/tmp/phase3-err.txt
  local got=$?
  set -e
  if [[ "$got" == "$want" ]]; then
    ok "$label"
  else
    bad "$label" "exit=$got want=$want; stderr=$(head -c 200 /tmp/phase3-err.txt | tr '\n' ' ')"
  fi
}

echo "== Phase 3 negative verify =="
echo "ROOT=$ROOT"

# --- Plugin rules / skills projection ---
for f in sdd-vibe-entry sdd-shape-no-code sdd-deploy-p4 sdd-codex-cli; do
  if [[ -L "$HOME/.cursor/rules/${f}.mdc" || -f "$HOME/.cursor/rules/${f}.mdc" ]]; then
    ok "cursor-rule:$f"
  else
    bad "cursor-rule:$f" "missing ~/.cursor/rules/${f}.mdc (run make install-cursor)"
  fi
done

if [[ -L "$HOME/.cursor/skills/vibe-coding" || -d "$HOME/.cursor/skills/vibe-coding" ]]; then
  ok "cursor-skill:vibe-coding"
else
  bad "cursor-skill:vibe-coding" "not linked"
fi

grep -q "第一个工具调用" "$ROOT/templates/.cursor/rules/sdd-vibe-entry.mdc" \
  && ok "rule-text:sdd-vibe-entry" || bad "rule-text:sdd-vibe-entry" "missing 第一个工具调用"
grep -q "project.kind" "$ROOT/templates/.cursor/rules/sdd-vibe-entry.mdc" \
  && ok "rule-text:sdd-vibe-entry-kind" || bad "rule-text:sdd-vibe-entry-kind" "missing project.kind gate"
grep -q "禁止默认假定" "$ROOT/templates/.cursor/rules/sdd-vibe-entry.mdc" \
  && ok "rule-text:sdd-vibe-entry-no-default-software" || bad "rule-text:sdd-vibe-entry-no-default-software" "missing no-default-software"
grep -q "不算" "$ROOT/templates/.cursor/rules/sdd-shape-no-code.mdc" \
  && ok "rule-text:sdd-shape-no-code" || bad "rule-text:sdd-shape-no-code" "missing"
grep -q "项目类型门" "$ROOT/templates/.cursor/rules/sdd-shape-no-code.mdc" \
  && ok "rule-text:sdd-shape-no-code-kind" || bad "rule-text:sdd-shape-no-code-kind" "missing kind gate"
test -f "$ROOT/skills/vibe-coding/references/project-kind.md" \
  && ok "skill:project-kind" || bad "skill:project-kind" "missing project-kind.md"
test -f "$ROOT/skills/design/references/project-init.md" \
  && ok "skill:project-init" || bad "skill:project-init" "missing project-init.md"
grep -q "≤5\|<=5\|整轮拍板" "$ROOT/skills/design/references/project-init.md" \
  && ok "skill:project-init-ask-cap" || bad "skill:project-init-ask-cap" "missing ≤5 ask cap"
grep -q "冷启动" "$ROOT/skills/vibe-coding/SKILL.md" \
  && ok "skill:vibe-cold-start-route" || bad "skill:vibe-cold-start-route" "missing 冷启动 route"
grep -q "Build ≠ Deploy" "$ROOT/templates/.cursor/rules/sdd-deploy-p4.mdc" \
  && ok "rule-text:sdd-deploy-p4" || bad "rule-text:sdd-deploy-p4" "missing"
grep -q "禁止" "$ROOT/templates/.cursor/rules/sdd-codex-cli.mdc" \
  && ok "rule-text:sdd-codex-cli" || bad "rule-text:sdd-codex-cli" "missing"

grep -q "FIRST ACTION" "$ROOT/skills/vibe-coding/SKILL.md" \
  && ok "skill:vibe-coding-FIRST-ACTION" || bad "skill:vibe-coding-FIRST-ACTION" "missing"

# --- product-judgment gate (UI decision layer) ---
test -f "$ROOT/skills/vibe-coding/references/design-standards/product-judgment.md" \
  && ok "skill:product-judgment" || bad "skill:product-judgment" "missing product-judgment.md"
grep -q "product-judgment.md" "$ROOT/skills/vibe-coding/references/design-standards/LOAD-MAP.md" \
  && ok "skill:load-map-judgment" || bad "skill:load-map-judgment" "LOAD-MAP missing product-judgment"
grep -q "Job Brief" "$ROOT/skills/vibe-coding/references/design-standards/LOAD-MAP.md" \
  && ok "skill:load-map-job-brief" || bad "skill:load-map-job-brief" "LOAD-MAP missing Job Brief field"
grep -q "product-judgment.md" "$ROOT/skills/design/SKILL.md" \
  && ok "skill:design-judgment" || bad "skill:design-judgment" "design SKILL missing product-judgment"
grep -q "FIRST ACTION" "$ROOT/skills/testing/SKILL.md" \
  && grep -q "product-judgment.md" "$ROOT/skills/testing/SKILL.md" \
  && ok "skill:testing-judgment-first" || bad "skill:testing-judgment-first" "testing SKILL missing FIRST ACTION→product-judgment"
grep -q "product-judgment.md" "$ROOT/skills/testing/references/ux-walkthrough.md" \
  && grep -q "FIRST ACTION" "$ROOT/skills/testing/references/ux-walkthrough.md" \
  && ok "skill:ux-walkthrough-judgment" || bad "skill:ux-walkthrough-judgment" "ux-walkthrough missing judgment FIRST ACTION"
grep -q "detect_job_brief" "$ROOT/skills/spec/scripts/check_spec.py" \
  && ok "skill:check-spec-job-brief" || bad "skill:check-spec-job-brief" "check_spec missing detect_job_brief"

# --- preflight-rail ---
tmp=$(mktemp -d)
git -C "$tmp" init -q
mkdir -p "$tmp/apps"
echo 'x' >"$tmp/apps/hello.ts"
expect_exit 1 "preflight-rail:dirty-business" \
  bash "$ROOT/scripts/preflight-rail.sh" --cwd "$tmp"
expect_exit 0 "preflight-rail:authorized" \
  bash "$ROOT/scripts/preflight-rail.sh" --cwd "$tmp" --authorized

tmp2=$(mktemp -d)
git -C "$tmp2" init -q
mkdir -p "$tmp2/docs/product"
echo 'shape' >"$tmp2/docs/product/note.md"
git -C "$tmp2" add -A
git -C "$tmp2" -c user.email=t@t -c user.name=t commit -qm init
expect_exit 0 "preflight-rail:docs-clean" \
  bash "$ROOT/scripts/preflight-rail.sh" --cwd "$tmp2"
rm -rf "$tmp" "$tmp2"

# --- codex-dispatch gates ---
DISPATCH="$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"
expect_exit 2 "dispatch:reject-multi-slice" \
  bash "$DISPATCH" --cwd "$ROOT" --unit build --spec fake --slice S1 -- \
  "do remaining slices S1|S2 now"
expect_exit 2 "dispatch:reject-no-slice" \
  bash "$DISPATCH" --cwd "$ROOT" --unit build --spec fake -- \
  "implement the feature with no slice marker"
expect_exit 2 "dispatch:reject-goal-without-approve" \
  env GOAL_APPROVED=0 bash "$DISPATCH" --cwd "$ROOT" --unit goal --spec fake -- \
  "full spec please"

# --- require-falsify ---
flog=$(mktemp -d)
expect_exit 1 "falsify:missing-log" \
  bash "$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh" \
  --log-dir "$flog" --run-id r1
echo 'offset0!=offset1' >"$flog/r1_falsify.log"
expect_exit 1 "falsify:no-verdict-pass" \
  bash "$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh" \
  --log-dir "$flog" --run-id r1
printf '%s\n' 'offset0!=offset1' 'VERDICT: S1 FAIL' >"$flog/r2_falsify.log"
expect_exit 1 "falsify:verdict-fail" \
  bash "$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh" \
  --log-dir "$flog" --run-id r2
printf '%s\n' 'offset0!=offset1' 'VERDICT: S1 PASS' >"$flog/r3_falsify.log"
expect_exit 0 "falsify:verdict-pass" \
  bash "$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh" \
  --log-dir "$flog" --run-id r3
rm -rf "$flog"

# --- check_run_honesty ---
set +e
python3 - <<'PY'
import importlib.util, sys, os
from pathlib import Path
plugin = Path(os.environ["PHASE3_ROOT"])
spec = importlib.util.spec_from_file_location(
    "check_spec", plugin / "skills/spec/scripts/check_spec.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
r = m.Report()
run = """
- 状态：`acceptance-passed`
- 当前模式：`build`
- 是否可以交付：`可交付`
- P2 发布方案（执行序 / sidecar 采纳或延期）：
- P3 验证方案（冒烟层勾选）：
- Deploy / rollback（P5）：ran make deploy
"""
m.check_run_honesty(Path("demo"), run, r, structure_only=False)
sys.exit(0 if r.errors >= 4 else 1)
PY
cs=$?
set -e
if [[ $cs -eq 0 ]]; then
  ok "check_spec:deliver+deploy-negative"
else
  bad "check_spec:deliver+deploy-negative" "expected >=4 honesty errors"
fi

# --- Hosts ---
AGENTDECK="${PHASE3_AGENTDECK:-/home/zcx/code/agentdeck}"
BI="${PHASE3_BI:-/home/zcx/code/bi-kaonai-dashboard}"
DATASAGE="${PHASE3_DATASAGE:-/home/zcx/code/data-sage}"

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
  if grep -Eq '已降权|路由降权' "$DATASAGE/.agents/skills/spec-generate/SKILL.md"; then
    ok "host:datasage-spec-generate-deprecated"
  else
    bad "host:datasage-spec-generate-deprecated" "no deprecation marker"
  fi
  if grep -Eq 'archived|归档' "$DATASAGE/docs/guides/factory-workflow.md"; then
    ok "host:datasage-factory-archived"
  else
    bad "host:datasage-factory-archived" "factory-workflow not archived"
  fi
else
  skip "host:datasage" "not found"
fi

if [[ -d "$AGENTDECK" ]]; then
  if grep -q '禁止' "$AGENTDECK/.cursor/rules/01-first-principles.mdc" \
    && grep -q 'spec-generate' "$AGENTDECK/.cursor/rules/01-first-principles.mdc"; then
    ok "host:agentdeck-no-spec-generate"
  else
    bad "host:agentdeck-no-spec-generate" "01-first-principles not updated"
  fi
  if grep -q '58-docs-backfill' "$AGENTDECK/AGENTS.md"; then
    bad "host:agentdeck-ghost-58" "AGENTS still cites 58-docs-backfill"
  else
    ok "host:agentdeck-ghost-58-cleared"
  fi
  if grep -q '适配器' "$AGENTDECK/.cursor/skills/deploy/SKILL.md" \
    && grep -q '适配器' "$AGENTDECK/.cursor/skills/verify-ui/SKILL.md"; then
    ok "host:agentdeck-adapters"
  else
    bad "host:agentdeck-adapters" "deploy/verify-ui missing 适配器"
  fi
else
  skip "host:agentdeck" "not found"
fi

echo
echo "======== SUMMARY ========"
printf '%s\n' "${RESULTS[@]}"
echo "-------------------------"
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"

cat <<'EOF'

======== MANUAL (new Cursor chats after Reload Window) ========
M1 Shape@agentdeck: 「讨论上传方案，禁止改码」→ first tool Read vibe-coding; only docs/product
M2 Entry@bi: no @skill → still Read vibe-coding first (alwaysApply)
M3 Deploy@bi: 「批准 Build」only → must NOT touch prod; need Deploy+P4
M4 Verify@agentdeck: refuse 可交付 without role×path falsify
M5 Codex: no CallMcpTool user-codex; only codex-dispatch.sh
M6 data-sage: 「写个产品 Spec」→ plugin five-piece, not spec-generate
M7 UX走查@任意宿主: first Reads 含 product-judgment + LOAD-MAP（可用 make eval-skill-load）
EOF

[[ "$FAIL" -eq 0 ]]
