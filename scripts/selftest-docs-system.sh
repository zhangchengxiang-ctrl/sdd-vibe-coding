#!/usr/bin/env bash
# Offline self-test: the SDD docs-system standard is shipped, self-consistent and checkable.
#
#   1. a full scaffold produces every directory the docs map claims (iterations, requests,
#      runbooks, reports) with typed templates, and AGENTS.md declares `SDD archive dir`
#   2. the plugin's OWN scaffold passes the plugin's OWN checker (placement + metadata + links)
#   3. the checker has teeth: an undeclared dir / a doc without metadata warn; a dead link
#      fails once it exceeds --max-broken
#   4. `minimal` stays minimal; `SDD gap register:` stops a second register being scaffolded
#   5. the slicing rules live in the spec skill and the plan template
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="$ROOT/scripts/scaffold.sh"; CHECK="$ROOT/scripts/check-docs.sh"
pass=0; fail=0
ok()  { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }
expect() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mk() { mkdir -p "$1" && git -C "$1" init -q; }

# ---- 1. full scaffold ---------------------------------------------------------------------
F="$TMP/full"; mk "$F"; bash "$SCAFFOLD" "$F" >"$TMP/full.log" 2>&1
for p in iterations/README.md iterations/_template/README.md iterations/_template/baseline.md \
         iterations/_template/decisions.md iterations/_template/release.md iterations/_template/retro.md \
         operations/requests/README.md operations/requests/_template.md operations/runbooks/README.md \
         reports/README.md reports/_template.md; do
  expect "scaffold writes docs/$p" test -f "$F/docs/$p"
done
expect "AGENTS.md declares SDD archive dir" grep -qE '^- SDD archive dir: archive$' "$F/AGENTS.md"

# ---- 2. self-consistency: our scaffold passes our checker ----------------------------------------
bash "$CHECK" "$F" >"$TMP/c1.log" 2>&1
expect "fresh scaffold passes check-docs with 0 warnings" grep -q 'warnings=0 broken_links=0' "$TMP/c1.log"
for f in iterations/_template/README.md operations/requests/_template.md reports/_template.md; do
  expect "template $f carries full metadata" bash -c "head -8 '$F/docs/$f' | grep -q '^type:' && head -8 '$F/docs/$f' | grep -q '^updated:' && head -8 '$F/docs/$f' | grep -q '^owner:'"
done

# ---- 3. the checker has teeth ------------------------------------------------------------------
mkdir -p "$F/docs/mystuff" && echo "# x" > "$F/docs/mystuff/a.md"
bash "$CHECK" "$F" >"$TMP/c2.log" 2>&1
expect "undeclared top-level dir warns" grep -q 'placement: top-level dir `mystuff/`' "$TMP/c2.log"
printf '# no front matter\n' > "$F/docs/reports/oops-20260101.md"
bash "$CHECK" "$F" >"$TMP/c3.log" 2>&1
expect "typed doc without metadata warns" grep -q 'metadata:.*reports/oops-20260101.md' "$TMP/c3.log"
printf '[dead](./nope.md)\n' >> "$F/docs/reports/oops-20260101.md"
bash "$CHECK" "$F" --max-broken 0 >"$TMP/c4.log" 2>&1; rc0=$?
bash "$CHECK" "$F" --max-broken 5 >"$TMP/c5.log" 2>&1; rc5=$?
expect "dead link fails when above --max-broken"   test "$rc0" -eq 1
expect "dead link passes when within --max-broken" test "$rc5" -eq 0

# ---- 3b. --since: existing documents are not retro-fitted ----------------------------------------
S="$TMP/since"; mk "$S"; bash "$SCAFFOLD" "$S" >/dev/null 2>&1
printf '# old report, no metadata\n' > "$S/docs/reports/old-20200101.md"
git -C "$S" add -A
GIT_COMMITTER_DATE="2020-01-01T00:00:00" git -C "$S" -c user.email=t@t -c user.name=t commit -q --date="2020-01-01T00:00:00" -m old
printf '# new report, no metadata\n' > "$S/docs/reports/new-20261119.md"
bash "$CHECK" "$S" >"$TMP/s0.log" 2>&1
bash "$CHECK" "$S" --since 2026-01-01 >"$TMP/s1.log" 2>&1
expect "without --since the old doc is flagged"          grep -q 'old-20200101.md' "$TMP/s0.log"
expect "--since skips a doc added before the date"       bash -c "grep -q 'check-docs: warnings=' '$TMP/s1.log' && ! grep -q 'old-20200101.md' '$TMP/s1.log'"
expect "--since still flags a doc that is not in git yet" grep -q 'new-20261119.md' "$TMP/s1.log"
# a document moved today is still an old document
mkdir -p "$S/docs/operations/requests" && git -C "$S" mv docs/reports/old-20200101.md docs/operations/requests/old-moved.md
git -C "$S" -c user.email=t@t -c user.name=t commit -q -m move
bash "$CHECK" "$S" --since 2026-01-01 >"$TMP/s2.log" 2>&1
expect "--since follows renames: a moved old doc is not new" bash -c "grep -q 'check-docs: warnings=' '$TMP/s2.log' && ! grep -q 'old-moved.md' '$TMP/s2.log'"

# ---- 4. minimal stays minimal; gap-register binding --------------------------------------------
M="$TMP/min"; mk "$M"; bash "$SCAFFOLD" "$M" --profile minimal >"$TMP/min.log" 2>&1
expect "minimal does not create iterations/" test ! -e "$M/docs/iterations"
expect "minimal does not create reports/"    test ! -e "$M/docs/reports"
G="$TMP/gap"; mk "$G"; mkdir -p "$G/docs/architecture"; echo "# register" > "$G/docs/architecture/11-gap-register.md"
printf '# a\n\n- SDD docs root: docs\n- SDD gap register: docs/architecture/11-gap-register.md\n' > "$G/AGENTS.md"
bash "$SCAFFOLD" "$G" >"$TMP/gap.log" 2>&1
expect "declared gap register: no second product/gap-register.md" test ! -e "$G/docs/product/gap-register.md"
N="$TMP/nogap"; mk "$N"; printf '# a\n\n- SDD docs root: docs\n- SDD gap register: docs/missing.md\n' > "$N/AGENTS.md"
bash "$SCAFFOLD" "$N" >"$TMP/nogap.log" 2>&1
expect "declared but missing file: default register is still created" test -f "$N/docs/product/gap-register.md"
expect "no declaration: default register is created" test -f "$F/docs/product/gap-register.md"

# ---- 5. slicing rules are in the spec skill and plan template ------------------------------------
expect "spec skill has 切分互斥与并行"       grep -q '### 切分互斥与并行' "$ROOT/skills/spec/SKILL.md"
expect "spec skill defines 文件::符号"       grep -q '文件::符号' "$ROOT/skills/spec/SKILL.md"
expect "spec skill names the 独立开关 axis"  grep -q '独立开关' "$ROOT/skills/spec/SKILL.md"
expect "plan template explains 触及路径"     grep -q '触及路径. 写 .文件. 或 .文件::符号.' "$ROOT/templates/docs/specs/_template/plan.md"

# ---- 6. check_spec warns when a new Spec does not declare its write set ---------------------------------
CHECK_SPEC="$ROOT/skills/spec/scripts/check_spec.py"
W="$TMP/ws"; mk "$W"; bash "$SCAFFOLD" "$W" >/dev/null 2>&1
mkspec() {  # $1 = id, $2 = VERSION status, $3 = python expr rewriting plan text `t`
  local d="$W/docs/specs/$1"; cp -r "$ROOT/templates/docs/specs/_template" "$d"
  sed -i "s/^| \*\*状态\*\* | .*/| **状态** | \`$2\` |/" "$d/VERSION.md"
  python3 - "$d/plan.md" "$3" <<'PY'
import sys
p, expr = sys.argv[1], sys.argv[2]
t = open(p, encoding="utf-8").read()
t = eval(expr)
open(p, "w", encoding="utf-8").write(t)
PY
}
ROW='| S1 | | T-001, T-002 | | | |'
mkspec v1-empty draft "t"                                                             # untouched template
mkspec v1-nocol draft "t.replace('| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |','| 切片 ID | 入口 | 完成定义 | 依赖 | 备注 |').replace('|---|---|---|---|---|---|','|---|---|---|---|---|').replace('$ROW','| S1 | | T-001 | | |')"
mkspec v1-dir   draft "t.replace('$ROW','| S1 | | T-001 | backend/x/ | | |')"
mkspec v1-ok    draft "t.replace('$ROW','| S1 | | T-001 | backend/x/a.py、backend/x/b.py::fn | | |')"
mkspec v1-done  verifying "t.replace('| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |','| 切片 ID | 入口 | 完成定义 | 依赖 | 备注 |').replace('|---|---|---|---|---|---|','|---|---|---|---|---|').replace('$ROW','| S1 | | T-001 | | |')"
for s in empty nocol dir ok done; do python3 "$CHECK_SPEC" "$W" "v1-$s" --skip-agents >"$TMP/w-$s.log" 2>&1; done
expect "untouched template: empty 触及路径 warns"       grep -q 'WARN.*v1-empty/plan.md: 切片 S1 的 `触及路径` 为空' "$TMP/w-empty.log"
expect "slice table without the column warns"           grep -q 'WARN.*v1-nocol/plan.md: 切片表缺 `触及路径` 列' "$TMP/w-nocol.log"
expect "a directory instead of a file warns"            grep -q 'WARN.*写了目录而不是文件：backend/x/' "$TMP/w-dir.log"
expect "file and file::symbol entries do not warn"      bash -c "! grep -q '触及路径' '$TMP/w-ok.log'"
expect "a shipped (verifying) Spec is not retro-fitted" bash -c "! grep -q '触及路径' '$TMP/w-done.log'"
expect "the write-set check never raises an ERROR"      bash -c "! grep -hE '^ERROR.*触及路径' '$TMP'/w-*.log"

# ---- 7. overlap: same iteration across Specs, and across slices inside one Spec --------------------------
setiter() { printf '\n| **iteration** | %s |\n' "$2" >> "$W/docs/specs/$1/VERSION.md"; }
ws() { echo "| S1 | | T-001 | $1 | | |"; }
mkspec x1 draft "t.replace('$ROW','$(ws 'backend/e.py::execute_query')')"; setiter x1 it1
mkspec x2 draft "t.replace('$ROW','$(ws 'backend/e.py::execute_query')')"; setiter x2 it1
mkspec x3 draft "t.replace('$ROW','$(ws 'backend/e.py::other_fn')')";      setiter x3 it1
mkspec x4 draft "t.replace('$ROW','$(ws 'backend/e.py::execute_query')')"; setiter x4 it2
mkspec x5 verifying "t.replace('$ROW','$(ws 'backend/e.py')')";            setiter x5 it1
mkspec x6 built-dev "t.replace('$ROW','$(ws 'backend/e.py::execute_query')')"; setiter x6 it1
mkspec x7 archived "t.replace('$ROW','$(ws 'backend/e.py::execute_query')')";  setiter x7 it1
mkspec y1 draft "t.replace('$ROW','| S1 | | T-001 | backend/f.py | | |\\n| S2 | | T-002 | backend/f.py | — | |')"
mkspec y2 draft "t.replace('$ROW','| S1 | | T-001 | backend/f.py | | |\\n| S2 | | T-002 | backend/f.py | S1 | |')"
python3 "$CHECK_SPEC" "$W" --all --skip-agents >"$TMP/ov-all.log" 2>&1
expect "same iteration, same symbol: warns"                    grep -q '迭代 it1: x1 与 x2 的触及路径相交' "$TMP/ov-all.log"
expect "same iteration, different symbols: no warning"         bash -c "! grep -E '迭代 it1: x(1|2) 与 x3|迭代 it1: x3 与 x(1|2)' '$TMP/ov-all.log'"
expect "different iteration: no warning"                       bash -c "! grep -E '迭代 it2' '$TMP/ov-all.log'"
expect "a verifying Spec still competes (repairs edit files)"  grep -qE '迭代 it1:.*x5' "$TMP/ov-all.log"
expect "an unknown status word still competes (built-dev)"    grep -qE '迭代 it1: (x[1-5] 与 x6|x6 与 x[1-5])' "$TMP/ov-all.log"
expect "...and its vocabulary warning says so"                grep -q 'x6/VERSION.md: 状态.*按「仍在施工」参与重叠检查' "$TMP/ov-all.log"
expect "an archived Spec does not compete"                    bash -c "! grep -E '迭代 it1:.*x7' '$TMP/ov-all.log'"
expect "inside one Spec: overlap without dependency warns"     grep -q 'y1/plan.md: 切片 S1 与 S2 的触及路径相交且互无依赖' "$TMP/ov-all.log"
expect "inside one Spec: overlap with a dependency is fine"    bash -c "! grep -q 'y2/plan.md: 切片 S1 与 S2' '$TMP/ov-all.log'"
python3 "$CHECK_SPEC" "$W" x1 --skip-agents >"$TMP/ov-one.log" 2>&1
expect "checking ONE Spec still finds its iteration peers"     grep -q '迭代 it1: x1 与 x2' "$TMP/ov-one.log"
expect "overlap is a warning, never an ERROR"                  bash -c "! grep -hE '^ERROR.*(相交|串行)' '$TMP'/ov-*.log"

# ---- 8. the version layer is part of the docs standard ---------------------------------------------------
STD="$ROOT/templates/docs/README.md"; ITR="$ROOT/templates/docs/iterations/README.md"
for f in quote.md requirements.md decisions.md; do
  expect "full scaffold writes the version's $f"            test -f "$F/docs/iterations/_template/$f"
done
expect "authority: user's words have one source"            grep -q '用户原话（逐字）.*quote\.md' "$STD"
expect "authority: user rulings have one source"            grep -q '用户裁定.*decisions\.md' "$STD"
expect "authority row for a round uses the version path"    bash -c "! grep -q '\`iterations/<id>/\`' '$STD'"
expect "reserved path explains the version layer"           grep -q '^| `iterations/` | 版本层' "$STD"
expect "placement: where the user's words go"               grep -q '^| 用户说的原话 |' "$STD"
expect "placement: where requirements and 待裁定 go"         grep -q '^| 这一轮要满足什么、待用户拍板什么 |' "$STD"
expect "placement: closing moves nothing"                   grep -q '版本与其中的 Spec 关闭后原地不动' "$STD"
expect "metadata: iteration closes as archived (= close-iteration)" grep -q '^| iteration | `draft → active → archived \\| cancelled`' "$STD"
grep -q 'status: archived' "$ROOT/scripts/close-iteration.sh"; ci=$?
expect "...and close-iteration really writes archived"      test "$ci" -eq 0
expect "precedence: what the user wants is ruled by quote.md" grep -q '需求冲突' "$STD"
expect "standard has a 版本布局与读序 section"                grep -q '^## 版本布局与读序' "$STD"
expect "read order starts at the version's quote"           grep -q 'README → quote → requirements → decisions' "$STD"
expect "Shape lands a version"                              grep -q 'Shape 产出一个版本' "$STD"
expect "closing flow names close-iteration"                 grep -q 'close-iteration' "$STD"
expect "version index lists no status column"               bash -c "! grep -q '^| 迭代 | 目标 | 状态 |' '$ITR'"
F8="$TMP/full8"; mk "$F8"; bash "$SCAFFOLD" "$F8" >/dev/null 2>&1
mkdir -p "$F8/docs/iterations/2026-11/w3/demo" && cp "$F8/docs/iterations/_template/"*.md "$F8/docs/iterations/2026-11/w3/demo/"
cp -r "$F8/docs/specs/_template" "$F8/docs/iterations/2026-11/w3/demo/s1"
bash "$CHECK" "$F8" >"$TMP/c8.log" 2>&1
expect "a scaffolded version with a Spec inside passes check-docs (0 warnings)" grep -q 'warnings=0' "$TMP/c8.log"

# ---- 9. three kinds of document, five rules, and the plugin agrees with itself ------------------------------
SK="$ROOT/skills"; TP="$ROOT/templates"
expect "standard defines 三类文档 (常青 / 在途 / 记录)"        bash -c "grep -q '^## 三类文档' '$STD' && grep -q '常青' '$STD' && grep -q '在途' '$STD' && grep -q '记录' '$STD'"
for n in 1 2 3 4 5; do
  expect "standard has rule $n of 五条规则"                    bash -c "sed -n '/^## 五条规则/,/^## [^五]/p' '$STD' | grep -q '^$n\\. \\*\\*'"
done
expect "placement table tags every row with its kind"        bash -c "rows=\$(sed -n '/^### 这份文档该放哪/,/^## 五条规则/p' '$STD' | grep '^| ' | grep -v '^| 这份文档\\|^|---'); [[ -n \"\$rows\" ]] && ! echo \"\$rows\" | awk -F'|' '{print \$3}' | grep -vqE '常青|在途|记录|归档|模板'"
STALE="$(grep -rnE 'docs/specs/<(id|SPEC_ID)>|`specs/<id>/' "$SK" "$TP" --include=*.md 2>/dev/null | grep -vE '历史|版本层之前|只读|legacy|不要再建|不再新建' || true)"
expect "no skill or template still sends new Specs to docs/specs/<id>/" test -z "$STALE"
[[ -n "$STALE" ]] && echo "$STALE" | sed 's/^/      /' | head -12
expect "states.md: archived stays in place"                  bash -c "grep -q '原地' '$SK/vibe-coding/references/states.md' && ! grep -q '勿只改状态位留原地' '$SK/vibe-coding/references/states.md'"
expect "VERSION template: archived stays in place"           bash -c "! grep -q '勿只改状态位' '$TP/docs/specs/_template/VERSION.md'"
DANGLING="$(grep -rln 'workflow-contract[^\n]*「状态词汇」\|workflow-contract.md\`*「状态词汇」' "$SK" "$TP" 2>/dev/null || true)"
grep -q '状态词汇' "$SK/vibe-coding/references/workflow-contract.md"; wc_has=$?
expect "no pointer to a 「状态词汇」 section workflow-contract does not have" bash -c "[[ -z '$DANGLING' || $wc_has -eq 0 ]]"
expect "status vocabulary claims one source, not two"         bash -c "[[ \$(grep -rl '状态词汇.*唯一真源\|唯一真源.*状态词汇' '$SK' '$TP' | wc -l) -eq 1 ]]"
expect "version layout and week rule written in ONE place"   bash -c "[[ \$(grep -rl '1～7 日' '$SK' '$TP' | wc -l) -eq 1 ]]"
expect "product package holds no delivery / acceptance files" bash -c "! grep -qE '05-delivery|06-acceptance' '$SK/design/references/product-package.md'"
expect "router (vibe-coding) knows the version layer"         grep -q 'iterations/<yyyy-mm>/<w>/<版本>/' "$SK/vibe-coding/SKILL.md"
expect "write-code gate (a) names the version"                grep -q '^| \*\*(a)\*\* |.*版本' "$SK/vibe-coding/references/gates.md"
expect "standard defines 版本 vs VERSION.md"                   grep -q 'VERSION.md` 是 Spec 的状态卡' "$STD"
# check-docs reads the whole placement section, ### sub-headings included
P9="$TMP/p9"; mk "$P9"; mkdir -p "$P9/docs/alpha" "$P9/docs/beta"
printf '# d\n\n## 这份文档该放哪\n\n### 常青\n\n| x | `alpha/` |\n\n### 在途\n\n| y | `beta/` |\n\n## 别的\n' > "$P9/docs/README.md"
bash "$CHECK" "$P9" >"$TMP/c9.log" 2>&1
expect "check-docs sees dirs declared under ### sub-headings"   bash -c "! grep -q 'beta/' '$TMP/c9.log'"

expect "placement: claims are for external resources, not files (= workspace-contract)" bash -c "grep -q '^| 外部共享资源.*| 在途 | \`claims.md\`' '$STD' && ! grep -q '谁正占着哪个文件' '$STD'"

echo "--- selftest-docs-system: pass=$pass fail=$fail ---"
[[ $fail -eq 0 ]]
