#!/usr/bin/env bash
# Offline self-test: shared-local write-set ownership (skills/vibe-coding/scripts/owners.py).
# The failure modes it guards are the ones that actually happened on a host with several sessions
# in one checkout: a commit sweeping in another session's staged files, and moving a directory
# another session was still writing.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OW="$ROOT/skills/vibe-coding/scripts/owners.py"
pass=0; fail=0
ok()  { echo "PASS  $1"; pass=$((pass + 1)); }
bad() { echo "FAIL  $1"; fail=$((fail + 1)); }
expect()  { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
refuse()  { local n="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$n"; else ok "$n"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
H="$TMP/h"; mkdir -p "$H/src/a" "$H/docs/x"; git -C "$H" init -q
for f in src/a/one.py src/a/two.py docs/x/README.md docs/y.md; do mkdir -p "$H/$(dirname $f)"; echo x > "$H/$f"; done
git -C "$H" add -A && git -C "$H" -c user.email=t@t -c user.name=t commit -qm init

expect "A claims a file and a symbol"                 python3 "$OW" claim "$H" --owner A --spec s1 src/a/one.py::run docs/x/
refuse "B cannot claim the same symbol"               python3 "$OW" claim "$H" --owner B src/a/one.py::run
refuse "B cannot claim the whole file A holds a symbol in" python3 "$OW" claim "$H" --owner B src/a/one.py
expect "B may claim another symbol in the same file"  python3 "$OW" claim "$H" --owner B src/a/one.py::other
refuse "B cannot claim a file under A's directory"    python3 "$OW" claim "$H" --owner B docs/x/README.md
refuse "B cannot move a parent dir of A's entries"    python3 "$OW" check "$H" --owner B docs/
expect "B may write an unrelated file"                python3 "$OW" check "$H" --owner B docs/y.md
python3 "$OW" list "$H" > "$TMP/list.log"
expect "list shows both owners"                       bash -c "grep -q '^A' '$TMP/list.log' && grep -q '^B' '$TMP/list.log'"
expect "declarations stay out of git (.sdd is local)" bash -c "[[ -f '$H/.sdd/owners/A.tsv' ]]"

# commit-guard: the shared index
echo y >> "$H/src/a/two.py"; git -C "$H" add src/a/two.py          # someone else stages this
echo y >> "$H/docs/x/README.md"; git -C "$H" add docs/x/README.md  # A's own work
python3 "$OW" commit-guard "$H" --owner A > "$TMP/g1.log" 2>&1; g1=$?
expect "guard fails when another session's file is staged" test "$g1" -eq 1
expect "...and names it"                              grep -q 'STAGED BUT NOT YOURS  src/a/two.py' "$TMP/g1.log"
git -C "$H" restore --staged src/a/two.py
expect "guard passes once only A's paths are staged"  python3 "$OW" commit-guard "$H" --owner A
echo z >> "$H/src/a/one.py"; git -C "$H" add src/a/one.py
python3 "$OW" commit-guard "$H" --owner A --allow src/a/one.py > "$TMP/g2.log" 2>&1; g2=$?
expect "guard fails on a staged path another owner declared" test "$g2" -eq 1
expect "...and names that owner"                      grep -q 'STAGED BUT DECLARED BY B  src/a/one.py' "$TMP/g2.log"
git -C "$H" restore --staged src/a/one.py

# release and stale
expect "B releases everything"                        python3 "$OW" release "$H" --owner B
expect "after release A may take the file"            python3 "$OW" claim "$H" --owner A src/a/one.py
sed -i 's/\t20[0-9-]*T[0-9:]*+00:00\t/\t2000-01-01T00:00:00+00:00\t/' "$H/.sdd/owners/A.tsv"
python3 "$OW" check "$H" --owner C src/a/one.py > "$TMP/s.log" 2>&1; sc=$?
expect "a stale declaration does not block"           test "$sc" -eq 0
expect "...but is reported"                           grep -q 'STALE' "$TMP/s.log"
refuse "owner name must be plain"                     python3 "$OW" claim "$H" --owner ../x src/a/one.py

# the contract and the standard say so
WC="$ROOT/skills/vibe-coding/references/workspace-contract.md"
expect "workspace-contract defines shared-local"       grep -q '^## 10. shared-local' "$WC"
expect "workspace-contract: commit-guard before every commit" grep -q 'commit-guard' "$WC"
expect "docs standard binds SDD workspace in AGENTS"   grep -q '^| `- SDD workspace: <模式>`' "$ROOT/templates/docs/README.md"
expect "Build rail points at shared-local"             grep -q 'shared-local' "$ROOT/skills/vibe-coding/references/rails.md"

echo "--- selftest-owners: pass=$pass fail=$fail ---"
[[ $fail -eq 0 ]]
