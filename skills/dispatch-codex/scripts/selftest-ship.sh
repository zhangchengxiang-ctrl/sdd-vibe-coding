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

check "ship-red-then-green" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --base "$BASE"
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
check "ship-nondiscriminating-fails" 1 bash "$SHIP" --host "$H2" --spec s1 --slice S1 --base "$BASE2"
saw "ship-names-nondiscriminating" 'baseline GREEN.*measures nothing'
saw "ship-skips-verify-without-red" 'SKIP +T-001 verify'

# --- red for the wrong reason is not evidence --------------------------------
H3="$TMP/h3"
mk_host "$H3" './no-such-binary-here --run'
BASE3="$(git -C "$H3" rev-parse HEAD)"
implement "$H3"
check "ship-env-red-fails" 1 bash "$SHIP" --host "$H3" --spec s1 --slice S1 --base "$BASE3"
saw "ship-names-env-red" 'red for the wrong reason'

H3b="$TMP/h3b"
mk_host "$H3b" 'node -e "require(\"nope-not-installed-anywhere\")"'
BASE3b="$(git -C "$H3b" rev-parse HEAD)"
implement "$H3b"
check "ship-missing-module-fails" 1 bash "$SHIP" --host "$H3b" --spec s1 --slice S1 --base "$BASE3b"
saw "ship-names-missing-module" 'red for the wrong reason'

# --- refusals ---------------------------------------------------------------
check "ship-refuses-without-base" 2 bash "$SHIP" --host "$H" --spec s1 --slice S1
saw "ship-explains-base-refusal" 'guessing which tree predates the change'

NG="$TMP/nongit"
mkdir -p "$NG/src"
cp -r "$H/docs" "$NG/docs"
echo IMPLEMENTED >"$NG/src/feature.txt"
check "ship-refuses-non-git" 2 bash "$SHIP" --host "$NG" --spec s1 --slice S1 --base "$BASE"

H4="$TMP/h4"
mk_host "$H4" '同 T-002。'
BASE4="$(git -C "$H4" rev-parse HEAD)"
check "ship-refuses-referential" 2 bash "$SHIP" --host "$H4" --spec s1 --slice S1 --base "$BASE4"
saw "ship-defers-to-throat" 'dispatch throat refuses|does not start with a runner-executable'

H5="$TMP/h5"
mk_host "$H5" 'human'
BASE5="$(git -C "$H5" rev-parse HEAD)"
check "ship-refuses-all-human" 2 bash "$SHIP" --host "$H5" --spec s1 --slice S1 --base "$BASE5"
saw "ship-explains-all-human" 'nothing for the runner to replay'

# --- verify-only must announce that it is not red-green ----------------------
check "ship-verify-only-runs" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --phase verify
saw "ship-verify-only-warns" 'NOT red-green evidence'

# --- resume skips what the same tree already witnessed -----------------------
check "ship-resume" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --base "$BASE" --resume
saw "ship-resume-skips" 'SKIP +T-001 (baseline|verify) \(already witnessed'

# --- a broken implementation must fail verify, not be reported green ---------
H6="$TMP/h6"
mk_host "$H6" "$GOOD_CMD"
BASE6="$(git -C "$H6" rev-parse HEAD)"
echo STILL_TODO >"$H6/src/feature.txt"
git -C "$H6" add -A
git -C "$H6" commit -qm "claims done, is not"
check "ship-catches-unimplemented" 1 bash "$SHIP" --host "$H6" --spec s1 --slice S1 --base "$BASE6"
saw "ship-names-verify-failure" 'FAIL +T-001 verify exit'

# --- --from-meta reads the baseline the dispatch recorded --------------------
META="$TMP/dispatch.meta.txt"
printf 'run_id=x\nbase_sha=%s\nrun_state=finished\n' "$BASE" >"$META"
check "ship-from-meta" 0 bash "$SHIP" --host "$H" --spec s1 --slice S1 --from-meta "$META"
printf 'run_id=x\nrun_state=finished\n' >"$TMP/nobase.meta.txt"
check "ship-refuses-meta-without-base" 2 \
  bash "$SHIP" --host "$H" --spec s1 --slice S1 --from-meta "$TMP/nobase.meta.txt"

echo "--- selftest-ship: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
