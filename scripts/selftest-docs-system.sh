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

echo "--- selftest-docs-system: pass=$pass fail=$fail ---"
[[ $fail -eq 0 ]]
