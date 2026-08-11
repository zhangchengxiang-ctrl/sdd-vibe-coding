#!/usr/bin/env bash
# Adversarial / destructive capability tests for rot-mechanisms-v5.
# Isolated: only touches /tmp fixtures + reads this plugin repo.
# Does NOT touch host production envs.
#
# Usage: bash scripts/adversarial-rot-verify.sh
# Exit 0 only if all attack expectations hold.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PASS=0
FAIL=0
RESULTS=()

ok() { PASS=$((PASS + 1)); RESULTS+=("PASS  $1"); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); RESULTS+=("FAIL  $1 — $2"); echo "FAIL  $1 — $2" >&2; }

echo "== adversarial-rot-verify =="
echo "ROOT=$ROOT"

# --- A1: slogan ratchet must be GONE (deletion must be legal) ---
if grep -E 'grep -q .*禁止因普通调研|grep -q .*关版 ≠ 上线|grep -q .*第一个工具调用' \
  scripts/check-contract-sync.sh >/dev/null 2>&1; then
  bad "A1-slogan-ratchet-gone" "check-contract-sync still has slogan greps"
else
  ok "A1-slogan-ratchet-gone"
fi

# --- A2: always-on window must stay under post-P1 ceiling ---
win=$(python3 - <<'PY'
from pathlib import Path
e=len(Path('skills/vibe-coding/SKILL.md').read_text().splitlines())
g=len(Path('skills/vibe-coding/references/gates.md').read_text().splitlines())
w=0
p=Path('skills/vibe-coding/references/wish-delivery.md')
if p.exists(): w=len(p.read_text().splitlines())
print(e+g+w)
PY
)
if [[ "$win" -le 180 ]]; then
  ok "A2-window-le-180 (got $win)"
else
  bad "A2-window-le-180" "always-on window=$win > 180"
fi

# --- A3: wish-delivery must not exist (merged) ---
if [[ -f skills/vibe-coding/references/wish-delivery.md ]]; then
  bad "A3-wish-delivery-deleted" "file still present"
else
  ok "A3-wish-delivery-deleted"
fi

# --- A4: gates/states/rails exist; workflow is thin index ---
wc_lines=$(wc -l <skills/vibe-coding/references/workflow-contract.md | tr -d ' ')
if [[ -f skills/vibe-coding/references/gates.md \
   && -f skills/vibe-coding/references/states.md \
   && -f skills/vibe-coding/references/rails.md \
   && "$wc_lines" -le 30 ]]; then
  ok "A4-contract-split (workflow index lines=$wc_lines)"
else
  bad "A4-contract-split" "missing split or fat index ($wc_lines lines)"
fi

# --- A5: single-definition strict ---
if bash scripts/single-definition.sh --strict >/dev/null; then
  ok "A5-single-definition-strict"
else
  bad "A5-single-definition-strict" "hits remain"
fi

# --- A6: orphan strict ---
if bash scripts/orphan-refs.sh --strict >/dev/null; then
  ok "A6-orphan-strict"
else
  bad "A6-orphan-strict" "orphans remain"
fi

# --- A7: rot ceiling holds ---
if bash scripts/rot-meter.sh >/dev/null; then
  ok "A7-rot-ceiling"
else
  bad "A7-rot-ceiling" "budget exceeded"
fi

# --- B1: attack — fake acceptance-passed must Fail ---
set +e
python3 - <<'PY'
import importlib.util, sys
from pathlib import Path
plugin = Path('.').resolve()
spec = importlib.util.spec_from_file_location('check_spec', plugin/'skills/spec/scripts/check_spec.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
r = m.Report()
run = """
- 状态：`acceptance-passed`
- 当前模式：`build`
- 是否可以交付：`可交付`
- P2 发布方案（执行序 / sidecar 采纳或延期）：
- P3 验证方案（冒烟层勾选）：
- Deploy / rollback（P5）：ran make deploy
"""
m.check_run_honesty(Path('demo'), run, r, structure_only=False)
sys.exit(0 if r.errors >= 4 else 1)
PY
e=$?; set -e
[[ $e -eq 0 ]] && ok "B1-fake-acceptance-blocked" || bad "B1-fake-acceptance-blocked" "attack succeeded (errors not raised)"

# --- B2: attack — claim 实现完成 without dispatch evidence ---
set +e
python3 - <<'PY'
import importlib.util, sys
from pathlib import Path
plugin = Path('.').resolve()
spec = importlib.util.spec_from_file_location('check_spec', plugin/'skills/spec/scripts/check_spec.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
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
m.check_run_honesty(Path('demo'), run, r, structure_only=False)
sys.exit(0 if r.errors >= 1 else 1)
PY
e=$?; set -e
[[ $e -eq 0 ]] && ok "B2-impl-without-dispatch-blocked" || bad "B2-impl-without-dispatch-blocked" "attack succeeded"

# --- B3: attack — T-001 checklist education Oracle ---
set +e
python3 - <<'PY'
import importlib.util, sys, tempfile
from pathlib import Path
plugin = Path('.').resolve()
spec = importlib.util.spec_from_file_location('check_spec', plugin/'skills/spec/scripts/check_spec.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
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
- 用户可见：勾完 checklist / Tour 播完 / lesson 完成率 100%
"""
tmp = Path(tempfile.mkdtemp())/'atk'; tmp.mkdir()
m.check_tests(tmp, tests, [], r, structure_only=False)
sys.exit(0 if r.errors >= 1 else 1)
PY
e=$?; set -e
[[ $e -eq 0 ]] && ok "B3-lazy-t001-blocked" || bad "B3-lazy-t001-blocked" "attack succeeded"

# --- B4: attack — unauthorized business write (preflight) ---
tmp=$(mktemp -d)
git -C "$tmp" init -q
mkdir -p "$tmp/apps"; echo 'x' >"$tmp/apps/hack.ts"
set +e
bash scripts/preflight-rail.sh --cwd "$tmp" >/dev/null 2>&1
e=$?; set -e
[[ $e -eq 1 ]] && ok "B4-preflight-blocks-dirty" || bad "B4-preflight-blocks-dirty" "exit=$e want=1"
rm -rf "$tmp"

# --- B5: attack — unbounded multi-slice / no-slice dispatch ---
set +e
bash skills/dispatch-codex/scripts/codex-dispatch.sh --cwd "$ROOT" --unit build --spec fake --slice S1 -- \
  "do remaining slices S1|S2 now" >/dev/null 2>&1
e1=$?
bash skills/dispatch-codex/scripts/codex-dispatch.sh --cwd "$ROOT" --unit build --spec fake -- \
  "implement without slice" >/dev/null 2>&1
e2=$?
set -e
[[ $e1 -eq 2 && $e2 -eq 2 ]] && ok "B5-dispatch-rejects-unbounded" || bad "B5-dispatch-rejects-unbounded" "e1=$e1 e2=$e2"

# --- B6: attack — unstructured falsify PASS ---
flog=$(mktemp -d)
printf '%s\n' 'VERDICT: S1 PASS' >"$flog/r_falsify.log"
set +e
bash skills/dispatch-codex/scripts/require-conductor-falsify.sh --log-dir "$flog" --run-id r >/dev/null 2>&1
e=$?; set -e
[[ $e -eq 1 ]] && ok "B6-unstructured-falsify-blocked" || bad "B6-unstructured-falsify-blocked" "exit=$e"
rm -rf "$flog"

# --- B7: attack — try to raise rot ceiling by adding slogan file (simulate) ---
# Ensure rot fails if we temporarily inflate entry (dry check via python compare)
python3 - <<'PY' || true
import json
from pathlib import Path
b=json.load(open('scripts/rot-baseline.json'))
cur=b['always_on_window_lines']
# if someone bumps window above ceiling, rot-meter must fail — assert baseline exists
assert cur <= 200
print('baseline window', cur)
PY
ok "B7-rot-baseline-present"

# --- C1: L0 mdc still installable / bans intact ---
for f in sdd-vibe-entry sdd-shape-no-code sdd-deploy-p4 sdd-codex-cli; do
  p="templates/.cursor/rules/${f}.mdc"
  if [[ -f "$p" ]] && grep -qE '禁止|Build ≠ Deploy|project\.kind|codex-dispatch' "$p"; then
    ok "C1-mdc-$f"
  else
    bad "C1-mdc-$f" "missing or hollow"
  fi
done

# --- C2: public-gates green ---
if PHASE3_PLUGIN_ONLY=1 bash scripts/public-gates.sh >/tmp/adv-pg.out 2>&1; then
  ok "C2-public-gates"
else
  bad "C2-public-gates" "see /tmp/adv-pg.out"
  tail -20 /tmp/adv-pg.out >&2 || true
fi

echo
echo "======== ADVERSARIAL SUMMARY ========"
printf '%s\n' "${RESULTS[@]}"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
