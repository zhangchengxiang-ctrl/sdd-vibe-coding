#!/usr/bin/env bash
# Offline gates for ship.sh — the red-green replay runner. No Codex required.
# Run from plugin root: bash skills/dispatch-codex/scripts/selftest-ship.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SHIP="$ROOT/skills/dispatch-codex/scripts/ship.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {   # name expected-exit -- cmd…
  local name="$1" expect="$2"; shift 2
  set +e
  "$@" >"$TMP/out.log" 2>&1
  local st=$?
  set -e
  if [[ "$st" -eq "$expect" ]]; then
    echo "PASS $name (exit $st)"; pass=$((pass + 1))
  else
    echo "FAIL $name (exit $st expected $expect)" >&2
    sed 's/^/      /' "$TMP/out.log" | tail -6 >&2
    fail=$((fail + 1))
  fi
}
saw() {   # name pattern — the last run's output must contain it
  if grep -qE "$2" "$TMP/out.log"; then
    echo "PASS $1"; pass=$((pass + 1))
  else
    echo "FAIL $1 — output lacked /$2/" >&2
    sed 's/^/      /' "$TMP/out.log" | tail -6 >&2
    fail=$((fail + 1))
  fi
}

# --- fixture host: one slice, one Oracle, a real red→green transition ---------
mk_host() {   # dir cmd  → git repo whose baseline lacks the feature
  local h="$1" cmd="$2"
  mkdir -p "$h/docs/specs/s1" "$h/src"
  git -C "$h" init -q .
  git -C "$h" config user.email t@t
  git -C "$h" config user.name t
  cat >"$h/docs/specs/s1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | feature | T-001 | src/feature.txt | | oracle:unit |
EOF
  local f
  for f in VERSION.md contract.md run.md requirements.md; do
    printf '# %s\n\nbody for placeholder gates.\n' "$f" >"$h/docs/specs/s1/$f"
  done
  write_tests "$h" "$cmd"
  echo TODO >"$h/src/feature.txt"
  git -C "$h" add -A
  git -C "$h" commit -qm base
}
write_tests() {   # host cmd
  local h="$1" cmd="$2"
  {
    printf '# Tests\n\n## 索引\n\n| ID | R |\n|---|---|\n| T-001 | R-001 |\n'
    printf '\n## T-001 · feature is implemented\n\n### Given\n\n- repo\n\n### When\n\n1. run\n\n'
    printf '### Then（Oracle）\n\n- src/feature.txt contains IMPLEMENTED\n\n'
    printf '### 自动化\n\n- 命令：`%s`\n- 预期 Evidence Kind：`unit`\n' "$cmd"
  } >"$h/docs/specs/s1/tests.md"
}
# The baseline now travels in the dispatch meta, so the fixtures must use the real path
# rather than hand-passing --base: that is what production does, and the custody checks
# below only exist on this route.
mk_meta() {   # host base_sha [frozen-oracles-tsv] → prints the meta path
  local h="$1" b="$2" frz="${3:-}" d="$1/.codex-dispatch-logs" m rid
  mkdir -p "$d"
  # mktemp, not a counter: every caller uses `$(mk_meta …)`, which runs in a subshell, so an
  # incremented META_N never came back — two calls produced the same filename and the second
  # silently replaced the first. That made a two-dispatch fixture indistinguishable from one.
  m="$(mktemp "$d/run-XXXXXX.meta.txt")"
  rid="$(basename "$m" .meta.txt)"
  # A meta is custody only if the run it names left a completed transcript, so the fixture
  # leaves one too — otherwise these probes exercise a path production now refuses.
  printf '%s\n' '{"type":"turn.completed","spec":"s1"}' >"$d/${rid}.jsonl"
  { printf 'run_id=%s\nspec=s1\nbase_sha=%s\nrun_state=finished\n' "$rid" "$b"
    if [[ -n "$frz" ]]; then
      printf 'oracles_file=%s\noracles_sha256=%s\n' \
        "$frz" "$(LC_ALL=C sort "$frz" | sha256sum | cut -d' ' -f1)"
    fi
  } >"$m"
  printf '%s' "$m"
}
freeze_of() {   # host slice → writes the frozen tsv the dispatch would have written
  local h="$1" sl="$2" out
  out="$h/.codex-dispatch-logs/frozen-$sl.tsv"   # separate statement: `local a=$1 b=$a`
                                                # expands b before a is assigned
  mkdir -p "$(dirname "$out")"
  python3 "$ROOT/skills/dispatch-codex/scripts/build_context_pack.py" --json "$h" s1 "$sl" \
    | python3 -c '
import json, sys
for o in json.load(sys.stdin).get("oracles", []):
    print("\t".join([o.get("id",""), o.get("kind",""), o.get("cmd","").strip("`").strip()]))
' >"$out"
  printf '%s' "$out"
}

write_contract() {   # host [tests-cell] — a real Requirements table, so --oracles-all has P0 rows
  local h="$1" cell="${2:-T-001, T-002}"
  cat >"$h/docs/specs/s1/contract.md" <<EOF
# Contract

## Requirements

| ID | 需求 | 优先级 | 证据级 | AC 摘要（行为） | Tests |
|---|---|---|---|---|---|
| R-001 | feature lands | P0 | Verified | files change | $cell |
EOF
}

implement() {   # host — the change under test
  echo IMPLEMENTED >"$1/src/feature.txt"
  git -C "$1" add -A
  git -C "$1" commit -qm impl
}

H="$TMP/h1"
GOOD_CMD='bash -c "grep -q IMPLEMENTED src/feature.txt"'
mk_host "$H" "$GOOD_CMD"
BASE="$(git -C "$H" rev-parse HEAD)"
implement "$H"

check "ship-red-then-green" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --from-meta "$(mk_meta "$H" "$BASE")"
saw "ship-reports-baseline-red" 'OK +T-001 baseline RED'
saw "ship-reports-verify-green" 'OK +T-001 verify GREEN'

# Evidence must carry both halves with the tree each was witnessed on, or a close gate
# cannot tell red-green from green-only.
ev_ok() {
  python3 - "$H/.sdd-evidence/s1-S1.jsonl" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
got = {(r["phase"], r["verdict"]) for r in rows}
assert ("baseline", "red") in got and ("verify", "green") in got, got
assert len({r["tree"] for r in rows}) == 2, "both rows recorded against the same tree"
assert all(r["cmd"] and r["stdout_sha256"] for r in rows), rows
PY
}
check "ship-evidence-has-both-halves" 0 ev_ok

# --- the second line of defence: `bash -c true` passes the dispatch throat -----
# It is not a no-op *literal*, so check_spec accepts it. Only running it on a tree
# without the feature exposes that it measures nothing.
H2="$TMP/h2"
mk_host "$H2" 'bash -c true'
BASE2="$(git -C "$H2" rev-parse HEAD)"
implement "$H2"
check "ship-nondiscriminating-fails" 1 bash "$SHIP" --host "$H2" --spec s1 --slice S1 --from-meta "$(mk_meta "$H2" "$BASE2")"
saw "ship-names-nondiscriminating" 'baseline GREEN.*measures nothing'
saw "ship-skips-verify-without-red" 'SKIP +T-001 verify'

# --- red for the wrong reason is not evidence --------------------------------
H3="$TMP/h3"
mk_host "$H3" './no-such-binary-here --run'
BASE3="$(git -C "$H3" rev-parse HEAD)"
implement "$H3"
check "ship-env-red-fails" 1 bash "$SHIP" --host "$H3" --spec s1 --slice S1 --from-meta "$(mk_meta "$H3" "$BASE3")"
saw "ship-names-env-red" 'red for the wrong reason'

H3b="$TMP/h3b"
mk_host "$H3b" 'node -e "require(\"nope-not-installed-anywhere\")"'
BASE3b="$(git -C "$H3b" rev-parse HEAD)"
implement "$H3b"
check "ship-missing-module-fails" 1 bash "$SHIP" --host "$H3b" --spec s1 --slice S1 --from-meta "$(mk_meta "$H3b" "$BASE3b")"
saw "ship-names-missing-module" 'red for the wrong reason'

# --- the judge must predate the work (maker != grader) -----------------------
# Attack: point the Oracle at a test file that does not exist yet. Baseline is red only
# because there is no test, so the implementer can satisfy red→green by writing its own
# fixture. Measured on 108 real machine Oracles: 11 path tokens resolve to nothing, all
# of them in already-closed Specs.
H7="$TMP/h7"
mk_host "$H7" 'bash -c "test -f tests/new.test.sh && bash tests/new.test.sh"'
BASE7="$(git -C "$H7" rev-parse HEAD)"
mkdir -p "$H7/tests"
printf '#!/usr/bin/env bash\nexit 0\n' >"$H7/tests/new.test.sh"
git -C "$H7" add -A
git -C "$H7" commit -qm "implementer writes its own judge"
check "ship-missing-judge-fails" 1 bash "$SHIP" --host "$H7" --spec s1 --slice S1 --from-meta "$(mk_meta "$H7" "$BASE7")"
saw "ship-names-maker-grader" 'judge does not exist yet|maker'

# No false positive: the same command when the test predates the change.
H8="$TMP/h8"
mk_host "$H8" 'bash -c "grep -q IMPLEMENTED src/feature.txt && bash tests/pre.test.sh"'
mkdir -p "$H8/tests"
printf '#!/usr/bin/env bash\nexit 0\n' >"$H8/tests/pre.test.sh"
git -C "$H8" add -A
git -C "$H8" commit -qm "judge exists at baseline"
BASE8="$(git -C "$H8" rev-parse HEAD)"
implement "$H8"
check "ship-existing-judge-passes" 0 bash "$SHIP" --host "$H8" --spec s1 --slice S1 --from-meta "$(mk_meta "$H8" "$BASE8")"

# An output path is not a judge: `--out dist/report.json` must not trip the check.
H9="$TMP/h9"
mk_host "$H9" 'bash -c "mkdir -p dist && grep -q IMPLEMENTED src/feature.txt && printf ok > dist/report.json"'
BASE9="$(git -C "$H9" rev-parse HEAD)"
implement "$H9"
check "ship-output-path-is-not-a-judge" 0 bash "$SHIP" --host "$H9" --spec s1 --slice S1 --from-meta "$(mk_meta "$H9" "$BASE9")"

# An absolute-path judge outside the repo (isolated runner) is judged by that path itself.
# Regression: it was joined to the tree root, so every external runner read as "missing".
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/ext-judge.sh"
H9B="$TMP/h9b"
mk_host "$H9B" "bash -c \"grep -q IMPLEMENTED src/feature.txt && bash $TMP/ext-judge.sh\""
BASE9B="$(git -C "$H9B" rev-parse HEAD)"
implement "$H9B"
check "ship-external-absolute-judge-passes" 0 bash "$SHIP" --host "$H9B" --spec s1 --slice S1 --from-meta "$(mk_meta "$H9B" "$BASE9B")"
H9C="$TMP/h9c"
mk_host "$H9C" 'bash -c "grep -q IMPLEMENTED src/feature.txt && bash /nonexistent-dir/judge.sh"'
BASE9C="$(git -C "$H9C" rev-parse HEAD)"
implement "$H9C"
check "ship-missing-absolute-judge-still-fails" 1 bash "$SHIP" --host "$H9C" --spec s1 --slice S1 --from-meta "$(mk_meta "$H9C" "$BASE9C")"

# Bytecode an oracle leaves in the reusable baseline worktree is not dirt. Regression: the second run
# died with "stale baseline worktree ... is dirty" and the operator had to rm -rf it by hand.
H10="$TMP/h10"
mk_host "$H10" 'bash -c "mkdir -p src/__pycache__ && : > src/__pycache__/m.cpython-311.pyc && grep -q IMPLEMENTED src/feature.txt"'
BASE10="$(git -C "$H10" rev-parse HEAD)"
implement "$H10"
M10="$(mk_meta "$H10" "$BASE10")"
check "ship-first-run-with-bytecode-oracle" 0 bash "$SHIP" --host "$H10" --spec s1 --slice S1 --from-meta "$M10"
check "ship-second-run-ignores-bytecode-in-baseline" 0 bash "$SHIP" --host "$H10" --spec s1 --slice S1 --from-meta "$M10"

# --- refusals ---------------------------------------------------------------
check "ship-refuses-without-base" 2 bash "$SHIP" --host "$H" --spec s1 --slice S1
saw "ship-explains-base-refusal" 'guessing which tree predates the change'

NG="$TMP/nongit"
mkdir -p "$NG/src"
cp -r "$H/docs" "$NG/docs"
echo IMPLEMENTED >"$NG/src/feature.txt"
check "ship-refuses-non-git" 2 bash "$SHIP" --host "$NG" --spec s1 --slice S1 --from-meta "$(mk_meta "$NG" "$BASE")"

H4="$TMP/h4"
mk_host "$H4" '同 T-002。'
BASE4="$(git -C "$H4" rev-parse HEAD)"
check "ship-refuses-referential" 2 bash "$SHIP" --host "$H4" --spec s1 --slice S1 --from-meta "$(mk_meta "$H4" "$BASE4")"
saw "ship-defers-to-throat" 'dispatch throat refuses|does not start with a runner-executable'

H5="$TMP/h5"
mk_host "$H5" 'human'
BASE5="$(git -C "$H5" rev-parse HEAD)"
check "ship-refuses-all-human" 2 bash "$SHIP" --host "$H5" --spec s1 --slice S1 --from-meta "$(mk_meta "$H5" "$BASE5")"
saw "ship-explains-all-human" 'nothing for the runner to replay'

# --- verify-only must announce that it is not red-green ----------------------
check "ship-verify-only-runs" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --phase verify
saw "ship-verify-only-warns" 'NOT red-green evidence'

# --- resume skips what the same tree already witnessed -----------------------
check "ship-resume" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --from-meta "$(mk_meta "$H" "$BASE")" --resume
saw "ship-resume-skips" 'SKIP +T-001 (baseline|verify) \(already witnessed'

# --- a broken implementation must fail verify, not be reported green ---------
H6="$TMP/h6"
mk_host "$H6" "$GOOD_CMD"
BASE6="$(git -C "$H6" rev-parse HEAD)"
echo STILL_TODO >"$H6/src/feature.txt"
git -C "$H6" add -A
git -C "$H6" commit -qm "claims done, is not"
check "ship-catches-unimplemented" 1 bash "$SHIP" --host "$H6" --spec s1 --slice S1 --from-meta "$(mk_meta "$H6" "$BASE6")"
saw "ship-names-verify-failure" 'FAIL +T-001 verify exit'

# --- --from-meta reads the baseline the dispatch recorded --------------------
META="$(mk_meta "$H" "$BASE")"
check "ship-from-meta" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --from-meta "$META"
mkdir -p "$H/.codex-dispatch-logs"
printf 'run_id=x\nrun_state=finished\n' >"$H/.codex-dispatch-logs/nobase.meta.txt"
check "ship-refuses-meta-without-base" 2 bash "$SHIP" --host "$H" --spec s1 --slice S1 \
  --from-meta "$H/.codex-dispatch-logs/nobase.meta.txt"

# --- baseline custody: the judged party may not choose its own baseline -------
# Scenario the review handed us: --base pointing at a tree that already contains the feature
# turns red→green into a formality. A meta is also just a file, so its location must be the
# dispatcher's log dir, and --base may not quietly overrule what the dispatch recorded.
check "ship-refuses-bare-base" 2 bash "$SHIP" --host "$H" --spec s1 --slice S1 --base "$BASE"
saw "ship-explains-bare-base" 'lets the judged party pick its own baseline'
check "ship-manual-base-with-optin" 0 env SHIP_ALLOW_MANUAL_BASE=1 \
  bash "$SHIP" --host "$H" --spec s1 --slice S1 --base "$BASE"
prov_ok() {   # the opt-in must leave a mark, or nobody downstream can tell
  grep -q '"base_provenance": *"manual-unverified"' "$H/.sdd-evidence/s1-S1.jsonl"
}
check "ship-records-manual-provenance" 0 prov_ok

printf 'run_id=x\nbase_sha=%s\n' "$BASE" >"$TMP/elsewhere.meta.txt"
check "ship-refuses-meta-outside-log-dir" 2 bash "$SHIP" --host "$H" --spec s1 --slice S1 \
  --from-meta "$TMP/elsewhere.meta.txt"
saw "ship-explains-meta-location" 'must live in a .codex-dispatch-logs dir'

HEADSHA="$(git -C "$H" rev-parse HEAD)"
check "ship-refuses-base-contradicting-meta" 2 bash "$SHIP" --host "$H" --spec s1 --slice S1 \
  --from-meta "$META" --base "$HEADSHA"
saw "ship-explains-base-conflict" "contradicts base_sha"

# --- the Oracle must be the frozen one, not whatever tests.md says now --------
# Attack from the review: after dispatch, rewrite the Oracle to `bash -c '[ -d .git ]'`.
# A detached worktree has .git as a FILE, the host has it as a directory, so that command is
# red on the baseline and green in the host while never touching the feature.
HD="$TMP/hdrift"
mk_host "$HD" "$GOOD_CMD"
BASED="$(git -C "$HD" rev-parse HEAD)"
FRZ="$(freeze_of "$HD" S1)"
MD="$(mk_meta "$HD" "$BASED" "$FRZ")"
implement "$HD"
check "ship-frozen-oracle-passes" 0 bash "$SHIP" --host "$HD" --spec s1 --slice S1 --from-meta "$MD"
write_tests "$HD" 'bash -c "[ -d .git ]"'
check "ship-refuses-oracle-drift" 2 bash "$SHIP" --host "$HD" --spec s1 --slice S1 --from-meta "$MD"
saw "ship-explains-drift" 'oracle drift'
# Proof that the swapped Oracle really would have passed: without the freeze it does.
check "ship-drift-would-have-passed" 0 env SHIP_ALLOW_MANUAL_BASE=1 \
  bash "$SHIP" --host "$HD" --spec s1 --slice S1 --base "$BASED"
saw "ship-drift-was-exploitable" 'OK +T-001 verify GREEN'
printf 'x\n' >>"$FRZ"
check "ship-refuses-tampered-freeze" 2 bash "$SHIP" --host "$HD" --spec s1 --slice S1 --from-meta "$MD"
saw "ship-explains-freeze-tamper" 'does not match oracles_sha256'

# --- a hand-written evidence row is not a witness ----------------------------
# Attack from the review: append {"id":…,"phase":"baseline","verdict":"red"} and --resume
# skips the execution outright.
HF="$TMP/hforge"
mk_host "$HF" "$GOOD_CMD"
BASEF="$(git -C "$HF" rev-parse HEAD)"
MF="$(mk_meta "$HF" "$BASEF")"
implement "$HF"
mkdir -p "$HF/.sdd-evidence"
python3 - "$HF/.sdd-evidence/s1-S1.jsonl" "$BASEF" <<'PY'
import json, sys
ev, base = sys.argv[1:3]
with open(ev, "w", encoding="utf-8") as fh:
    for phase, tree, verdict in (("baseline", base, "red"), ("verify", base, "green")):
        fh.write(json.dumps({"id": "T-001", "phase": phase, "tree": tree,
                             "verdict": verdict, "cmd": "forged"}) + "\n")
PY
check "ship-ignores-forged-rows" 0 bash "$SHIP" --host "$HF" --spec s1 --slice S1 \
  --from-meta "$MF" --resume
saw "ship-reran-despite-forgery" 'OK +T-001 baseline RED'

# The stronger forgery: the evidence file is readable, so copy a real row's oracle digest and
# point it at a log that is gone. Only re-hashing the log it names catches this — without that
# check the digest alone would let the row stand in for the run.
HF2="$TMP/hforge2"
mk_host "$HF2" "$GOOD_CMD"
BASEF2="$(git -C "$HF2" rev-parse HEAD)"
MF2="$(mk_meta "$HF2" "$BASEF2")"
implement "$HF2"
bash "$SHIP" --host "$HF2" --spec s1 --slice S1 --from-meta "$MF2" >/dev/null 2>&1
python3 - "$HF2/.sdd-evidence/s1-S1.jsonl" <<'PY2'
import json, sys
ev = sys.argv[1]
rows = [json.loads(l) for l in open(ev, encoding="utf-8") if l.strip()]
digest = next(r["oracle_sha256"] for r in rows)
with open(ev, "w", encoding="utf-8") as fh:
    for r in rows:
        fh.write(json.dumps({**r, "oracle_sha256": digest,
                             "log": r["log"] + ".gone"}) + "\n")
PY2
rm -rf "$HF2/.sdd-evidence/logs"
check "ship-ignores-rows-with-copied-digest" 0 bash "$SHIP" --host "$HF2" --spec s1 --slice S1 \
  --from-meta "$MF2" --resume
saw "ship-reran-despite-copied-digest" 'OK +T-001 baseline RED'

# Stale-but-genuine evidence: the rows below were really produced, logs and all — for a
# DIFFERENT Oracle. Re-freezing after an edit must not let yesterday's run stand in for a
# command that has never executed. That is what binding each row to the Oracle digest buys.
HR="$TMP/hrefreeze"
mk_host "$HR" "$GOOD_CMD"
BASER="$(git -C "$HR" rev-parse HEAD)"
MR1="$(mk_meta "$HR" "$BASER" "$(freeze_of "$HR" S1)")"
implement "$HR"
bash "$SHIP" --host "$HR" --spec s1 --slice S1 --from-meta "$MR1" >/dev/null 2>&1
write_tests "$HR" 'bash -c "grep -q IMPLEMENTED src/feature.txt && test -s src/feature.txt"'
MR2="$(mk_meta "$HR" "$BASER" "$(freeze_of "$HR" S1)")"
check "ship-reruns-after-refreeze" 0 bash "$SHIP" --host "$HR" --spec s1 --slice S1 \
  --from-meta "$MR2" --resume
saw "ship-reran-after-oracle-changed" 'OK +T-001 baseline RED'

# --- verify runs the working tree, so evidence must not name a bare commit ----
HW="$TMP/hdirty"
mk_host "$HW" "$GOOD_CMD"
BASEW="$(git -C "$HW" rev-parse HEAD)"
MW="$(mk_meta "$HW" "$BASEW")"
echo IMPLEMENTED >"$HW/src/feature.txt"    # deliberately NOT committed
check "ship-dirty-tree-runs" 0 bash "$SHIP" --host "$HW" --spec s1 --slice S1 --from-meta "$MW"
saw "ship-announces-dirty" 'verify tree is DIRTY'
dirty_ok() { grep -q '"tree": *"[0-9a-f]*+dirty\.' "$HW/.sdd-evidence/s1-S1.jsonl"; }
check "ship-evidence-marks-dirty" 0 dirty_ok

# --- a hang is not a verdict -------------------------------------------------
HT="$TMP/hang"
mk_host "$HT" 'bash -c "[ -d .git ] && exit 0; while :; do :; done"'
BASET="$(git -C "$HT" rev-parse HEAD)"
MT="$(mk_meta "$HT" "$BASET")"
implement "$HT"
check "ship-timeout-is-not-red" 1 env SHIP_TIMEOUT_SEC=2 \
  bash "$SHIP" --host "$HT" --spec s1 --slice S1 --from-meta "$MT"
saw "ship-names-timeout-inconclusive" 'red for the wrong reason'

# --- a linked dep dir must not smuggle the working tree into the baseline -----
HL="$TMP/hlink"
mk_host "$HL" "$GOOD_CMD"
BASEL="$(git -C "$HL" rev-parse HEAD)"
ML="$(mk_meta "$HL" "$BASEL")"
implement "$HL"
mkdir -p "$HL/node_modules/@app" "$HL/packages/check"
ln -s "$HL/packages/check" "$HL/node_modules/@app/check"
check "ship-refuses-workspace-link-escape" 2 bash "$SHIP" --host "$HL" --spec s1 --slice S1 \
  --from-meta "$ML"
saw "ship-explains-link-escape" 'escapes into the working tree'
check "ship-link-escape-avoidable" 0 env SHIP_LINK= \
  bash "$SHIP" --host "$HL" --spec s1 --slice S1 --from-meta "$ML"

# --- a whole-Spec replay must cover P0 T-ids that no slice names -------------
# The replay set used to come from plan.md 完成定义. A slice table is a work breakdown, so a
# P0 requirement mapping T-001,T-002 while every slice mentions only T-001 left T-002 out of
# the closing replay entirely — the missing-failure case is exactly what tends to be unsliced.
HU="$TMP/hunsliced"
mk_host "$HU" "$GOOD_CMD"
write_contract "$HU"
{
  printf '# Tests\n\n## 索引\n\n| ID | R |\n|---|---|\n| T-001 | R-001 |\n| T-002 | R-001 |\n'
  printf '\n## T-001 · feature\n\n### Given\n\n- repo\n\n### When\n\n1. run\n\n'
  printf '### Then（Oracle）\n\n- feature.txt says IMPLEMENTED\n\n'
  printf '### 自动化\n\n- 命令：`%s`\n- 预期 Evidence Kind：`unit`\n' "$GOOD_CMD"
  printf '\n## T-002 · sibling nobody sliced\n\n### Given\n\n- repo\n\n### When\n\n1. run\n\n'
  printf '### Then（Oracle）\n\n- other.txt says ALSO\n\n'
  printf '### 自动化\n\n- 命令：`bash -c "grep -q ALSO src/other.txt"`\n'
  printf -- '- 预期 Evidence Kind：`unit`\n'
} >"$HU/docs/specs/s1/tests.md"
echo TODO >"$HU/src/other.txt"
git -C "$HU" add -A
git -C "$HU" commit -qm "two P0 oracles, one of them unsliced"
BASEU="$(git -C "$HU" rev-parse HEAD)"
MU="$(mk_meta "$HU" "$BASEU")"
echo IMPLEMENTED >"$HU/src/feature.txt"
echo ALSO >"$HU/src/other.txt"
git -C "$HU" add -A
git -C "$HU" commit -qm impl
check "ship-whole-spec-covers-unsliced" 0 bash "$SHIP" --host "$HU" --spec s1 --from-meta "$MU"
saw "ship-replays-unsliced-oracle" 'OK +T-002 verify GREEN'
saw "ship-names-unsliced-oracle" 'no plan.md slice names: T-002'
# Contrast: a single dispatch unit is still scoped to its own slice.
check "ship-slice-stays-scoped" 0 bash "$SHIP" --host "$HU" --spec s1 --slice S1 --from-meta "$MU"
scoped_ok() { ! grep -q 'T-002' "$TMP/out.log"; }
check "ship-slice-excludes-other-oracles" 0 scoped_ok

# --- the close path must actually replay --------------------------------------
# These live here rather than in a close-gate selftest because the fixtures are here: what is
# being probed is that verify-deliver drives ship.sh at all. It shipped a whole increment
# with nothing requiring it, which is how "red-green is the close gate" stayed a claim.
VD="$ROOT/scripts/verify-deliver.sh"

HV="$TMP/hverify"
mk_host "$HV" 'bash -c true'
write_contract "$HV" "T-001"
BASEV="$(git -C "$HV" rev-parse HEAD)"
mk_meta "$HV" "$BASEV" >/dev/null
implement "$HV"
check "verify-deliver-fails-on-nondiscriminating" 1 bash "$VD" "$HV" s1
saw "verify-deliver-ran-the-replay" 'replay failed|baseline GREEN'

HV2="$TMP/hverify2"
mk_host "$HV2" "$GOOD_CMD"
write_contract "$HV2" "T-001"
BASEV2="$(git -C "$HV2" rev-parse HEAD)"
mk_meta "$HV2" "$BASEV2" >/dev/null
implement "$HV2"
# check_spec --closing will still refuse this fixture's run.md, so assert on the replay half:
# what matters is that the commands were replayed before any claim was read.
bash "$VD" "$HV2" s1 >"$TMP/out.log" 2>&1 || true
saw "verify-deliver-replays-red-then-green" 'OK +T-001 baseline RED'
# Not the banner verify-deliver echoes — check_spec's own output. With the python call
# deleted the heading would still print, and this probe would still have passed.
saw "verify-deliver-reaches-check-spec" '(ERROR|OK): s1'

HV3="$TMP/hverify3"
mk_host "$HV3" "$GOOD_CMD"
write_contract "$HV3" "T-001"
implement "$HV3"
bash "$VD" "$HV3" s1 >"$TMP/out.log" 2>&1 || true
saw "verify-deliver-warns-without-baseline" 'no .codex-dispatch-logs meta names spec=s1'
# Wiring, not logic: the probes in gate-cases call check_replay_evidence directly, so they
# stay green if nothing calls it. This one goes through the real CLI.
saw "verify-deliver-close-gate-demands-replay" 'red-green replay for T-001'

# A meta is a text file the implementer can write. Requiring the run it names to have left a
# jsonl carrying turn.completed means forging the baseline also means forging a transcript.
HV4="$TMP/hverify4"
mk_host "$HV4" "$GOOD_CMD"
write_contract "$HV4" "T-001"
BASEV4="$(git -C "$HV4" rev-parse HEAD)"
mkdir -p "$HV4/.codex-dispatch-logs"
printf 'run_id=forged\nspec=s1\nbase_sha=%s\nrun_state=finished\n' "$BASEV4" \
  >"$HV4/.codex-dispatch-logs/forged.meta.txt"
implement "$HV4"
bash "$VD" "$HV4" s1 >"$TMP/out.log" 2>&1 || true
saw "verify-deliver-skips-meta-without-transcript" 'skipping forged.meta.txt'
saw "verify-deliver-refuses-without-custody" 'no .codex-dispatch-logs meta names spec=s1'

# The transcript must be parsed, not grepped: `{"note":"turn.completed"}` is text.
printf '%s\n' '{"note":"turn.completed"}' >"$HV4/.codex-dispatch-logs/forged.jsonl"
bash "$VD" "$HV4" s1 >"$TMP/out.log" 2>&1 || true
saw "verify-deliver-rejects-textual-turn-completed" 'skipping forged.meta.txt'
printf '%s\n' '{"type":"turn.completed"}' >"$HV4/.codex-dispatch-logs/forged.jsonl"
bash "$VD" "$HV4" s1 >"$TMP/out.log" 2>&1 || true
saw "verify-deliver-accepts-real-turn-completed" 'baseline from forged.meta.txt'

# --- a whole-Spec close must survive per-slice freezes -------------------------
# The blocker the second review found: each dispatch freezes only its own slice's Oracles, so
# comparing one digest of the whole set against S1's frozen file called it drift when nothing
# had drifted — and no multi-slice Spec could ever close.
HM="$TMP/hmulti"
mk_host "$HM" "$GOOD_CMD"
write_contract "$HM" "T-001, T-002"
{
  printf '# Tests\n\n## 索引\n\n| ID | R |\n|---|---|\n| T-001 | R-001 |\n| T-002 | R-001 |\n'
  printf '\n## T-001 · a\n\n### Given\n\n- x\n\n### When\n\n1. y\n\n'
  printf '### Then（Oracle）\n\n- feature.txt says IMPLEMENTED\n\n'
  printf '### 自动化\n\n- 命令：`%s`\n- 预期 Evidence Kind：`unit`\n' "$GOOD_CMD"
  printf '\n## T-002 · b\n\n### Given\n\n- x\n\n### When\n\n1. y\n\n'
  printf '### Then（Oracle）\n\n- other.txt says ALSO\n\n'
  printf '### 自动化\n\n- 命令：`bash -c "grep -q ALSO src/other.txt"`\n'
  printf -- '- 预期 Evidence Kind：`unit`\n'
} >"$HM/docs/specs/s1/tests.md"
cat >"$HM/docs/specs/s1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | feature | T-001 | src/feature.txt | | oracle:unit |
| S2 | other | T-002 | src/other.txt | S1 | oracle:unit |
EOF
echo TODO >"$HM/src/other.txt"
git -C "$HM" add -A && git -C "$HM" commit -qm "two slices"
BASEM="$(git -C "$HM" rev-parse HEAD)"
MM="$(mk_meta "$HM" "$BASEM" "$(freeze_of "$HM" S1)")"   # only S1 frozen, as a real dispatch does
echo IMPLEMENTED >"$HM/src/feature.txt"; echo ALSO >"$HM/src/other.txt"
git -C "$HM" add -A && git -C "$HM" commit -qm impl
check "ship-whole-spec-with-partial-freeze" 0 bash "$SHIP" --host "$HM" --spec s1 --from-meta "$MM"
saw "ship-replays-both-oracles" 'OK +T-002 verify GREEN'
saw "ship-names-unfrozen-oracle" 'no dispatch froze T-002'
# Drift is still refused, now per T-id rather than as one digest of the set.
write_tests "$HM" 'bash -c "[ -d .git ]"'
python3 - "$HM" <<'PY2'
import sys
from pathlib import Path
# write_tests only writes T-001; restore T-002 so the only change is T-001's command
p = Path(sys.argv[1]) / "docs/specs/s1/tests.md"
s = p.read_text(encoding="utf-8")
s = s.replace("| T-001 | R-001 |", "| T-001 | R-001 |\n| T-002 | R-001 |")
s += ('\n## T-002 · b\n\n### Given\n\n- x\n\n### When\n\n1. y\n\n'
      '### Then（Oracle）\n\n- other.txt says ALSO\n\n'
      '### 自动化\n\n- 命令：`bash -c "grep -q ALSO src/other.txt"`\n')
p.write_text(s, encoding="utf-8")
PY2
check "ship-per-oracle-drift-refused" 2 bash "$SHIP" --host "$HM" --spec s1 --from-meta "$MM"
saw "ship-names-the-drifted-id" 'oracle drift on T-001'

# Two dispatches that froze one T-id differently: taking the newest would let a re-freeze
# replace the judge the first dispatch was held to. Its own host — reusing a fixture other
# probes have already mutated is how the first version of this probe ended up measuring drift.
HC="$TMP/hconflict"
mk_host "$HC" "$GOOD_CMD"
write_contract "$HC" "T-001"
BASEC="$(git -C "$HC" rev-parse HEAD)"
MC1="$(mk_meta "$HC" "$BASEC" "$(freeze_of "$HC" S1)")"
printf 'T-001\tmachine\tbash -c "grep -q SOMETHING_ELSE src/feature.txt"\n' \
  >"$HC/.codex-dispatch-logs/frozen-conflict.tsv"
mk_meta "$HC" "$BASEC" "$HC/.codex-dispatch-logs/frozen-conflict.tsv" >/dev/null
implement "$HC"
check "ship-conflicting-freezes-refused" 2 bash "$SHIP" --host "$HC" --spec s1 --from-meta "$MC1"
# The loop echoes "frozen differently" whether or not the refusal fires, so assert the die's
# own sentence — otherwise disabling the refusal leaves this green.
saw "ship-names-conflicting-freeze" 'two dispatches froze'

# An obligation cannot be closed by deleting it: a T-id a dispatch froze must still be a P0
# Oracle of the Spec.
HG="$TMP/hgone"
mk_host "$HG" "$GOOD_CMD"
write_contract "$HG" "T-001, T-002"
{
  printf '# Tests\n\n## 索引\n\n| ID | R |\n|---|---|\n| T-001 | R-001 |\n| T-002 | R-001 |\n'
  printf '\n## T-001 · a\n\n### Given\n\n- x\n\n### When\n\n1. y\n\n'
  printf '### Then（Oracle）\n\n- feature.txt says IMPLEMENTED\n\n'
  printf '### 自动化\n\n- 命令：`%s`\n- 预期 Evidence Kind：`unit`\n' "$GOOD_CMD"
  printf '\n## T-002 · b\n\n### Given\n\n- x\n\n### When\n\n1. y\n\n'
  printf '### Then（Oracle）\n\n- other.txt says ALSO\n\n'
  printf '### 自动化\n\n- 命令：`bash -c "grep -q ALSO src/other.txt"`\n'
  printf -- '- 预期 Evidence Kind：`unit`\n'
} >"$HG/docs/specs/s1/tests.md"
echo TODO >"$HG/src/other.txt"
git -C "$HG" add -A && git -C "$HG" commit -qm two
BASEG="$(git -C "$HG" rev-parse HEAD)"
MG="$(mk_meta "$HG" "$BASEG" "$(freeze_of "$HG" S1)")"
echo IMPLEMENTED >"$HG/src/feature.txt"; echo ALSO >"$HG/src/other.txt"
git -C "$HG" add -A && git -C "$HG" commit -qm impl
write_contract "$HG" "T-002"     # T-001 was frozen, then dropped from the mapping
check "ship-vanished-obligation-refused" 2 bash "$SHIP" --host "$HG" --spec s1 --from-meta "$MG"
saw "ship-names-vanished-obligation" 'no longer a P0 Oracle'

echo "--- selftest-ship: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
