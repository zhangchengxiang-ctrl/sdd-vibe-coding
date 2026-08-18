#!/usr/bin/env bash
# Phase 3 negative acceptance — behavioral gates (no slogan grep).
# Usage: bash scripts/phase3-negative-verify.sh
# Optional: PHASE3_PLUGIN_ONLY=1 (public CI; skip install projection)
# Host drift checks moved to scripts/host-drift.sh (manual; not in public-gates).
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
PLUGIN_ONLY="${PHASE3_PLUGIN_ONLY:-0}"

# --- Install projection existence (decision 1: keep) ---
if [[ "$PLUGIN_ONLY" != "1" ]]; then
  for f in sdd-vibe-entry; do
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
else
  skip "cursor-install-projection" "PHASE3_PLUGIN_ONLY=1"
fi

# --- Template / skill asset existence (not slogan content) ---
for rule in sdd-vibe-entry; do
  test -f "$ROOT/templates/.cursor/rules/${rule}.mdc" \
    && ok "rule-file:$rule" || bad "rule-file:$rule" "missing template"
done
for _sk in design spec testing deploy debug dispatch-codex; do
  grep -q "disable-model-invocation: true" "$ROOT/skills/$_sk/SKILL.md" \
    && ok "skill-dmi:$_sk" || bad "skill-dmi:$_sk" "missing disable-model-invocation"
done
test -f "$ROOT/skills/vibe-coding/references/project-kind.md" \
  && ok "skill:project-kind" || bad "skill:project-kind" "missing project-kind.md"
test -f "$ROOT/skills/design/references/project-init.md" \
  && ok "skill:project-init" || bad "skill:project-init" "missing project-init.md"
test -f "$ROOT/skills/vibe-coding/references/design-standards/product-judgment.md" \
  && ok "skill:product-judgment" || bad "skill:product-judgment" "missing product-judgment.md"
test -f "$ROOT/skills/vibe-coding/references/design-standards/LOAD-MAP.md" \
  && ok "skill:load-map" || bad "skill:load-map" "missing LOAD-MAP.md"

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
expect_exit 2 "dispatch:reject-unbounded-multi-slice" \
  bash "$DISPATCH" --cwd "$ROOT" --unit build --spec fake --slice S1 -- \
  "do remaining slices S1|S2 now"
expect_exit 2 "dispatch:reject-no-slice" \
  bash "$DISPATCH" --cwd "$ROOT" --unit build --spec fake -- \
  "implement the feature with no slice marker"
goal_gone() {
  local out
  out="$(env GOAL_APPROVED=1 bash "$DISPATCH" --cwd "$ROOT" --unit goal --spec fake -- \
    "full spec please" 2>&1)"
  # GOAL_APPROVED=1 on purpose: the old gate refused only when approval was missing, so a probe
  # run without it would stay green if that gate came back.
  grep -q 'unit goal is gone' <<<"$out"
}
expect_exit 0 "dispatch:goal-unit-gone" goal_gone

# --- the replay gate replaces the structured attestation ---
# Was: five expectations against require-conductor-falsify, a conductor-typed
# COMMAND + EXIT_CODE + VERDICT log. ship.sh replays the frozen Oracle on the dispatch's own
# baseline instead, so the negative that matters here is that a Spec cannot close on a replay
# nobody ran. The runner's own negatives live in selftest-ship.
rdir=$(mktemp -d)
mkdir -p "$rdir/docs/specs/s1"
expect_exit 1 "replay:no-evidence-no-anchor" \
  python3 -c "
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('cs', '$ROOT/skills/spec/scripts/check_spec.py')
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)
sys.exit(0 if cs.closing_anchor('', Path('$rdir/docs/specs/s1'), []) else 1)
"
mkdir -p "$rdir/.sdd-evidence/logs"
printf 'ok\n' >"$rdir/.sdd-evidence/logs/T-001-baseline.log"
printf '%s\n' '{"spec":"s1","id":"T-001","phase":"baseline","verdict":"red","log":"'"$rdir"'/.sdd-evidence/logs/T-001-baseline.log"}' \
  >"$rdir/.sdd-evidence/s1-all.jsonl"
expect_exit 0 "replay:log-on-disk-anchors" \
  python3 -c "
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('cs', '$ROOT/skills/spec/scripts/check_spec.py')
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)
sys.exit(0 if cs.closing_anchor('', Path('$rdir/docs/specs/s1'), []) else 1)
"
rm -rf "$rdir"

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
sys.exit(0 if r.errors >= 1 else 1)
PY
cs=$?
set -e
if [[ $cs -eq 0 ]]; then
  ok "check_spec:deliver+deploy-negative"
else
  bad "check_spec:deliver+deploy-negative" "expected honesty errors (P5 without P2/P3)"
fi

# --- T-001 lazy path oracle must Fail (scheme-antipatterns) ---
set +e
python3 - <<'PY'
import importlib.util, sys, os, tempfile
from pathlib import Path
plugin = Path(os.environ["PHASE3_ROOT"])
spec = importlib.util.spec_from_file_location(
    "check_spec", plugin / "skills/spec/scripts/check_spec.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
r = m.Report()
tests = """
## 索引
| ID | Type | R |
|----|------|---|
| T-001 | success | R-1 |

## T-001
### Given
- 新用户打开引导
### When
- 走完 checklist
### Then（Oracle）
- 用户可见：勾完 checklist / lesson 完成率 100%
- 副作用：无
"""
# minimal harness: call then_is_lazy + check_tests path
assert m.then_is_lazy_path_oracle("勾完 checklist / lesson 完成率 100%"), "detector miss"
tmp = Path(tempfile.mkdtemp()) / "lazy-oracle"
tmp.mkdir()
(tmp / "VERSION.md").write_text("status: draft\n", encoding="utf-8")
(tmp / "contract.md").write_text("# contract\n", encoding="utf-8")
(tmp / "plan.md").write_text("## 架构与设计边界\n- 边界：沿用现有\n", encoding="utf-8")
(tmp / "run.md").write_text("# run\n", encoding="utf-8")
(tmp / "tests.md").write_text(tests, encoding="utf-8")
m.check_tests(tmp, tests, [], r, structure_only=False)
sys.exit(0 if r.warnings >= 1 else 1)
PY
lo=$?
set -e
if [[ $lo -eq 0 ]]; then
  ok "check_spec:t001-lazy-oracle-negative"
else
  bad "check_spec:t001-lazy-oracle-negative" "expected T-001 checklist oracle to Warn"
fi

# --- Build 实现完成 without dispatch evidence must Fail ---
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
- 状态：`building`
- 当前模式：`build`
- 实现冻结时间：2026-08-11T00:00:00Z
oracle-freeze: intact
红绿证据: N/A · 无自动化
## 批次结果
| 结果 |
|------|
| Pass |
"""
m.check_run_honesty(Path("demo"), run, r, structure_only=False)
# expect fail for missing dispatch evidence
sys.exit(0 if r.errors >= 1 else 1)
PY
de=$?
set -e
if [[ $de -eq 0 ]]; then
  ok "check_spec:dispatch-evidence-negative"
else
  bad "check_spec:dispatch-evidence-negative" "expected missing dispatch evidence to Fail"
fi

# positive: override accepted
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
- 状态：`building`
- 当前模式：`build`
- 实现冻结时间：2026-08-11T00:00:00Z
oracle-freeze: intact
红绿证据: N/A · polish
override: polish · 用户本轮明示
## 批次结果
| 结果 |
|------|
| Pass |
"""
m.check_run_honesty(Path("demo"), run, r, structure_only=False)
# dispatch-related errors should be 0; other honesty may warn
sys.exit(0 if r.errors == 0 else 1)
PY
dp=$?
set -e
if [[ $dp -eq 0 ]]; then
  ok "check_spec:dispatch-override-positive"
else
  bad "check_spec:dispatch-override-positive" "override: polish · 用户本轮明示 should pass"
fi

# --- synonym lazy Oracle must Fail (rot H1) ---
set +e
python3 - <<'PY'
import importlib.util, sys, os, tempfile
from pathlib import Path
plugin = Path(os.environ["PHASE3_ROOT"])
spec = importlib.util.spec_from_file_location(
    "check_spec", plugin / "skills/spec/scripts/check_spec.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
phrases = [
    "新手任务单全部打钩，教学流程正式收官。",
    "导览动画走到末页并自动退场。",
    "侧滑面板弹出并停在展开态。",
    "textarea 获得焦点且闪烁光标。",
]
for p in phrases:
    if not m.then_is_lazy_path_oracle(p):
        print("miss", p, file=sys.stderr)
        sys.exit(1)
r = m.Report()
tests = """
## 索引
| ID | Type | R |
|----|------|---|
| T-001 | success | R-1 |
## T-001
### Given
- x
### When
- y
### Then（Oracle）
- 用户可见：右侧浮层滑入视野并保持展开。
"""
tmp = Path(tempfile.mkdtemp()) / "syn"
tmp.mkdir()
m.check_tests(tmp, tests, [], r, structure_only=False)
sys.exit(0 if r.warnings >= 1 else 1)
PY
sy=$?
set -e
if [[ $sy -eq 0 ]]; then
  ok "check_spec:t001-lazy-synonym-negative"
else
  bad "check_spec:t001-lazy-synonym-negative" "expected synonym lazy Oracle to Warn"
fi

# --- build euphemism without dispatch must Fail (rot H2) ---
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
- 当前模式：`build`
Build 已经交卷，功能代码全部落袋。
oracle-freeze: intact
红绿证据: red exit=1 · green exit=0
## 批次结果
| 结果 |
|------|
| Pass |
"""
m.check_run_honesty(Path("demo"), run, r, structure_only=False)
sys.exit(0 if r.errors >= 1 else 1)
PY
eu=$?
set -e
if [[ $eu -eq 0 ]]; then
  ok "check_spec:impl-euphemism-negative"
else
  bad "check_spec:impl-euphemism-negative" "expected euphemism without dispatch to Fail"
fi

# --- fake dispatch-run-id must Fail (rot H4) ---
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
- 当前模式：`build`
- 实现冻结时间：2026-08-11T00:00:00Z
oracle-freeze: intact
红绿证据: N/A · 无自动化
dispatch-run-id: totally-fake-id-999
## 批次结果
| 结果 |
|------|
| Pass |
"""
m.check_run_honesty(Path("demo"), run, r, structure_only=False)
sys.exit(0 if r.errors >= 1 else 1)
PY
fk=$?
set -e
if [[ $fk -eq 0 ]]; then
  ok "check_spec:fake-dispatch-id-negative"
else
  bad "check_spec:fake-dispatch-id-negative" "expected missing jsonl to Fail"
fi

# --- closing with empty Evidence must Fail (stamp no longer a gate) ---
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
- 当前模式：`verify`
- 是否可以交付：`可交付`
证伪: falsify done
## 已验证的用户结果
用户能完成主路径
### 追踪矩阵
| Requirement | Test | Implementation | Evidence | Result |
|---|---|---|---|---|
| R-001 | T-001 | | | Pass |
## 批次结果
| 结果 |
|------|
| Pass |
"""
m.check_run_honesty(Path("demo"), run, r, structure_only=False, closing=True)
sys.exit(0 if r.errors >= 1 else 1)
PY
fs=$?
set -e
if [[ $fs -eq 0 ]]; then
  ok "check_spec:closing-empty-evidence-negative"
else
  bad "check_spec:closing-empty-evidence-negative" "expected closing empty Evidence to Fail"
fi

echo
echo "======== SUMMARY ========"
printf '%s\n' "${RESULTS[@]}"
echo "-------------------------"
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"

cat <<'EOF'

======== MANUAL (new Cursor chats after Reload Window) ========
M1 Shape@agentdeck: 「/vibe-coding 讨论上传方案，禁止改码」→ first tool Read vibe-coding; only docs/product
M2 Entry@bi: 普通调研/SSH/取数（无高信号）→ 禁止先 Read vibe-coding；仅 /vibe-coding 或确认方案等才强制
M3 Deploy@bi: 「批准 Build」only → must NOT touch prod; need Deploy+P4
M4 Verify@agentdeck: refuse 可交付 without role×path red-green replay
M5 Codex: no CallMcpTool user-codex; only codex-dispatch.sh
M6 data-sage: 「写个产品 Spec」→ plugin five-piece, not spec-generate
M7 UX走查@任意宿主: first Reads 含 product-judgment + LOAD-MAP（可用 make eval-skill-load）
Host drift: make host-drift   # optional; not in public-gates
EOF

[[ "$FAIL" -eq 0 ]]
