#!/usr/bin/env bash
# Offline self-test: Specs live inside their version — docs/iterations/<yyyy-mm>/<w>/<version>/<spec>/.
#
#   1. spec_paths finds a version Spec, a legacy specs/<id>, a legacy archived Spec, and a version
#      by id; the version is recognised by README front matter, not by the bucket spelling; a
#      duplicate id is reported, never guessed
#   2. check_spec resolves a version Spec by id, `--all` includes it, and the same-version overlap
#      warning is decided by the DIRECTORY (no `iteration:` field needed)
#   3. check_spec warns for an in-flight Spec left in the legacy specs/<id>, and for an
#      `iteration:` field that contradicts the directory; never an ERROR
#   4. build_context_pack (the path ship / dispatch use) reads a version Spec
#   5. close-spec on a version Spec marks it archived IN PLACE (no move, no link rewrite);
#      a legacy Spec still moves to specs/<archive dir>/
#   6. close-iteration refuses while a member Spec is open or retro.md is the template, then sets
#      the version README to archived and moves nothing
#   7. the standard says so: spec skill, docs-root, iterations README, docs README, version template
#   8. a version carries the wish (quote / requirements / decisions) before any Spec, and
#      check-docs does not demand front matter from the Specs inside it
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/skills/spec/scripts/check_spec.py"
SP="$ROOT/skills/spec/scripts/spec_paths.py"
PACK="$ROOT/skills/dispatch-codex/scripts/build_context_pack.py"
pass=0; fail=0
ok()  { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }
expect() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

ROW='| S1 | | T-001, T-002 | | | |'
mkspec() {  # $1 = dir (relative to docs), $2 = status, $3 = 触及路径 cell
  local d="$H/docs/$1"; mkdir -p "$(dirname "$d")"; cp -r "$ROOT/templates/docs/specs/_template" "$d"
  sed -i "s/^| \*\*状态\*\* | .*/| **状态** | \`$2\` |/" "$d/VERSION.md"
  python3 - "$d/plan.md" "$ROW" "| S1 | | T-001 | $3 | | |" <<'PY'
import sys
p, old, new = sys.argv[1:4]
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.replace(old, new))
PY
}
commit() { git -C "$H" add -A && git -C "$H" -c user.email=t@t -c user.name=t commit -qm "$1"; }

H="$TMP/h"; mkdir -p "$H/docs/specs" "$H/docs/product"; git -C "$H" init -q
printf '# Agents\n\n- SDD archive dir: _archive\n' > "$H/AGENTS.md"
cp -r "$ROOT/templates/docs/specs/_template" "$H/docs/specs/_template"
cp -r "$ROOT/templates/docs/iterations" "$H/docs/iterations"
V="iterations/2026-11/w3/q1"
mkdir -p "$H/docs/$V" && cp "$H/docs/iterations/_template/"*.md "$H/docs/$V/"
mkdir -p "$H/docs/iterations/2026-12/w1/other" && cp "$H/docs/iterations/_template/"*.md "$H/docs/iterations/2026-12/w1/other/"
echo "# product" > "$H/docs/product/x.md"
mkspec "$V/a1" draft 'backend/e.py::execute_query'
mkspec "$V/a2" draft 'backend/e.py::execute_query'
mkspec "$V/a3" draft 'backend/e.py::other_fn'
mkspec "iterations/2026-12/w1/other/b1" draft 'backend/e.py::execute_query'
mkspec specs/legacy-wip draft 'backend/z.py'
mkspec specs/legacy-done verifying 'backend/z.py'
mkdir -p "$H/docs/specs/_archive/old1" && echo "# old" > "$H/docs/specs/_archive/old1/VERSION.md"
mkdir -p "$H/docs/$V/notes-not-a-spec" && echo "# scratch" > "$H/docs/$V/notes-not-a-spec/x.md"
printf '# notes\n\n[a1](%s/a1/VERSION.md) · [q1](%s/README.md#关闭条件)\n' "$V" "$V" > "$H/docs/notes.md"
commit init

# ---- 1. spec_paths ---------------------------------------------------------------------------------
expect "spec_paths finds a version Spec"            bash -c "[[ \"\$(python3 '$SP' find '$H' a1)\" == *'/docs/$V/a1' ]]"
expect "spec_paths finds a legacy specs/<id>"       bash -c "[[ \"\$(python3 '$SP' find '$H' legacy-wip)\" == *'/docs/specs/legacy-wip' ]]"
expect "spec_paths finds a legacy archived Spec"    bash -c "[[ \"\$(python3 '$SP' find '$H' old1)\" == *'/docs/specs/_archive/old1' ]]"
expect "spec_paths names the version"               bash -c "[[ \"\$(python3 '$SP' iteration '$H/docs/$V/a2')\" == q1 ]]"
expect "spec_paths finds a version by id"           bash -c "[[ \"\$(python3 '$SP' find-iteration '$H' q1)\" == *'/docs/$V' ]]"
expect "a dir without VERSION.md is not a Spec"     bash -c "python3 '$SP' find '$H' notes-not-a-spec; [[ \$? -eq 1 ]]"
expect "the _template version is not a version"     bash -c "python3 '$SP' find-iteration '$H' _template; [[ \$? -eq 1 ]]"
expect "spec_paths: unknown id exits 1"             bash -c "python3 '$SP' find '$H' nope; [[ \$? -eq 1 ]]"
cp -r "$H/docs/specs/legacy-done" "$H/docs/$V/legacy-done"
expect "spec_paths: duplicate id exits 3"           bash -c "python3 '$SP' find '$H' legacy-done; [[ \$? -eq 3 ]]"
rm -rf "$H/docs/$V/legacy-done"

# ---- 2. check_spec resolution, --all, directory-decided overlap ------------------------------------
python3 "$CHECK" "$H" a1 --skip-agents >"$TMP/c-a1.log" 2>&1
expect "check_spec resolves a version Spec by id"         grep -q '^== Spec a1 (full) ==' "$TMP/c-a1.log"
expect "...and does not report it missing"                 bash -c "! grep -q 'Spec path not a directory' '$TMP/c-a1.log'"
expect "same-version overlap found by directory alone"    grep -q '迭代 q1: a1 与 a2 的触及路径相交' "$TMP/c-a1.log"
expect "different symbols in one file: no overlap"        bash -c "! grep -E '迭代 q1: a(1|2) 与 a3|a3 与 a(1|2)' '$TMP/c-a1.log'"
expect "same symbol in ANOTHER version: no overlap"       bash -c "! grep -q 'b1' '$TMP/c-a1.log'"
python3 "$CHECK" "$H" --all --skip-agents >"$TMP/c-all.log" 2>&1
expect "--all includes version Specs"                      grep -q '^== Spec b1 (full) ==' "$TMP/c-all.log"
expect "--all still includes legacy Specs"                 grep -q '^== Spec legacy-wip (full) ==' "$TMP/c-all.log"
expect "--all never treats non-Spec dirs as Specs"         bash -c "! grep -qE '^== Spec (_template|_archive|old1|q1|w3|2026-11|notes-not-a-spec) ' '$TMP/c-all.log'"

# ---- 3. placement warnings -------------------------------------------------------------------------
python3 "$CHECK" "$H" legacy-wip --skip-agents >"$TMP/c-lw.log" 2>&1
expect "in-flight legacy Spec: placement WARN"             grep -q 'WARN.*legacy-wip: 在途 Spec 应放在 iterations/' "$TMP/c-lw.log"
python3 "$CHECK" "$H" legacy-done --skip-agents >"$TMP/c-ld.log" 2>&1
expect "shipped legacy Spec is a record: no placement WARN" bash -c "! grep -q '在途 Spec 应放在' '$TMP/c-ld.log'"
expect "a version Spec gets no placement WARN"             bash -c "! grep -q '在途 Spec 应放在' '$TMP/c-a1.log'"
printf '\n| **iteration** | it9 |\n' >> "$H/docs/$V/a3/VERSION.md"
python3 "$CHECK" "$H" a3 --skip-agents >"$TMP/c-a3.log" 2>&1
expect "iteration field contradicting the dir: WARN"       grep -q 'WARN.*a3: VERSION 的 iteration 写的是 it9，目录却在版本 q1 下' "$TMP/c-a3.log"
expect "placement is a warning, never an ERROR"            bash -c "! grep -hE '^ERROR.*(在途 Spec 应放在|目录却在版本)' '$TMP'/c-*.log"
git -C "$H" checkout -q -- "docs/$V/a3/VERSION.md"

# ---- 4. build_context_pack reads a version Spec ----------------------------------------------------
python3 "$PACK" "$H" a1 --list >"$TMP/pack.log" 2>&1
expect "build_context_pack finds the version Spec's plan"  bash -c "! grep -q 'plan.md not found' '$TMP/pack.log'"
expect "...and lists its slice"                             grep -q 'S1' "$TMP/pack.log"

# ---- 5. close-spec: in place for a version Spec, moved for a legacy one ----------------------------
bash "$ROOT/scripts/close-spec.sh" "$H" a1 --skip-verify-deliver >"$TMP/cs-a1.log" 2>&1
expect "close-spec on a version Spec finishes"             grep -q 'close-spec: DONE' "$TMP/cs-a1.log"
expect "...status archived in place"                       grep -q '^| \*\*状态\*\* | `archived` |' "$H/docs/$V/a1/VERSION.md"
expect "...nothing moved to specs/_archive/"               test ! -e "$H/docs/specs/_archive/a1"
expect "...change log says it stays in the version"        grep -q '留在版本 `q1` 目录内' "$H/docs/$V/a1/VERSION.md"
expect "...inbound link untouched"                         grep -q "($V/a1/VERSION.md)" "$H/docs/notes.md"
bash "$ROOT/scripts/close-spec.sh" "$H" a1 --skip-verify-deliver >"$TMP/cs-a1b.log" 2>&1
expect "close-spec twice: already closed, exit 0"          grep -q 'already closed' "$TMP/cs-a1b.log"
bash "$ROOT/scripts/close-spec.sh" "$H" legacy-done --skip-verify-deliver >"$TMP/cs-ld.log" 2>&1
expect "legacy Spec still moves to specs/_archive/"        test -d "$H/docs/specs/_archive/legacy-done"
commit closed-a1

# ---- 6. close-iteration -----------------------------------------------------------------------------
bash "$ROOT/scripts/close-iteration.sh" "$H" q1 >"$TMP/ci1.log" 2>&1; rc1=$?
expect "close-iteration refuses while Specs are open"      test "$rc1" -ne 0
expect "...and names them"                                  grep -q 'a2: draft' "$TMP/ci1.log"
for s in a2 a3; do sed -i 's/^| \*\*状态\*\* | .*/| **状态** | `cancelled` |/' "$H/docs/$V/$s/VERSION.md"; done
bash "$ROOT/scripts/close-iteration.sh" "$H" q1 >"$TMP/ci2.log" 2>&1; rc2=$?
expect "close-iteration refuses an untouched retro.md"     test "$rc2" -ne 0
expect "...and says why"                                    grep -q 'retro.md is still the template' "$TMP/ci2.log"
sed -i 's/^- 指标是否达成：$/- 指标是否达成：是，10.1% → 7.2%/' "$H/docs/$V/retro.md"
commit ready
bash "$ROOT/scripts/close-iteration.sh" "$H" q1 >"$TMP/ci3.log" 2>&1; rc3=$?
expect "close-iteration succeeds once members are closed"  test "$rc3" -eq 0
expect "...README status archived"                          grep -q '^status: archived' "$H/docs/$V/README.md"
expect "...nothing moved"                                   test -f "$H/docs/$V/a1/VERSION.md"
expect "...links into the version still resolve"           grep -q "($V/README.md#关闭条件)" "$H/docs/notes.md"
expect "...only README changed"                             bash -c "[[ \"\$(git -C '$H' status --porcelain)\" == ' M docs/$V/README.md' ]]"

# ---- 7. the standard says so -----------------------------------------------------------------------
expect "spec skill writes Specs into the version"            grep -q 'docs/iterations/<yyyy-mm>/<w>/<版本>/<id>/' "$ROOT/skills/spec/SKILL.md"
expect "docs-root documents the layout"                      grep -q 'iterations/<yyyy-mm>/<w>/<版本>/<spec-id>/' "$ROOT/skills/vibe-coding/references/docs-root.md"
expect "iterations README: directory is membership"          grep -q '目录即归属' "$ROOT/templates/docs/iterations/README.md"
expect "iterations README: a one-Spec change still gets a version" grep -q '只有一个 Spec 的小改动也建版本' "$ROOT/templates/docs/iterations/README.md"
expect "docs README: placement row points into the version"  grep -q 'iterations/<yyyy-mm>/<w>/<版本>/<id>/' "$ROOT/templates/docs/README.md"
expect "week bucket is defined by date, not weekday"          grep -q '1～7 日 `w1`' "$ROOT/templates/docs/README.md"
expect "version template is recognised as a version"         grep -q '^type: iteration' "$ROOT/templates/docs/iterations/_template/README.md"

# ---- 8. a version carries the wish: quote → requirements → decisions, then Specs ------------------------
for f in quote.md requirements.md decisions.md; do
  expect "version template has $f"                        test -f "$ROOT/templates/docs/iterations/_template/$f"
done
expect "quote template says verbatim and append-only"     grep -q '只追加' "$ROOT/templates/docs/iterations/_template/quote.md"
expect "requirements template has 待裁定"                  grep -q '## 待裁定' "$ROOT/templates/docs/iterations/_template/requirements.md"
expect "spec skill: no Spec while 待裁定 is open"          grep -q '待裁定项未在 `decisions.md` 有结论时不切' "$ROOT/skills/spec/SKILL.md"
expect "design skill lands a wish in the version dir"     grep -q '原话进 `quote.md`' "$ROOT/skills/design/SKILL.md"
rm -rf "$H/docs/$V/notes-not-a-spec"       # leave only the version's own (front-mattered) docs and its Specs
bash "$ROOT/scripts/check-docs.sh" "$H" >"$TMP/cd.log" 2>&1
expect "check-docs does not ask Specs inside a version for front matter" bash -c "! grep -q 'metadata:' '$TMP/cd.log'"
mkdir -p "$H/docs/$V/notes-not-a-spec"
printf '# no front matter\n' > "$H/docs/$V/notes-not-a-spec/loose.md"
bash "$ROOT/scripts/check-docs.sh" "$H" >"$TMP/cd2.log" 2>&1
expect "...but still asks other version docs"             grep -q 'metadata:' "$TMP/cd2.log"

echo "--- selftest-iteration-layout: pass=$pass fail=$fail ---"
[[ $fail -eq 0 ]]
