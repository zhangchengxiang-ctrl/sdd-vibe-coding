#!/usr/bin/env bash
# Offline gates for dispatch-codex hard doors (no Codex required).
# Run from plugin root: bash skills/dispatch-codex/scripts/selftest-gates.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSERT="$ROOT/skills/dispatch-codex/scripts/assert_plan_artifacts.py"
WISH="$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  local name="$1" expect="$2"
  shift 2
  set +e
  "$@" >"$TMP/last.log" 2>&1
  local st=$?
  set -e
  if [[ "$st" -eq "$expect" ]]; then
    echo "PASS $name (exit $st)"
    pass=$((pass + 1))
  else
    echo "FAIL $name (exit $st expected $expect)" >&2
    fail=$((fail + 1))
  fi
}

saw_gates() {   # name pattern — the last check's output must contain it, so a refusal is
  # attributed to the gate under test rather than to any other exit-2 path
  if grep -qE "$2" "$TMP/last.log" 2>/dev/null; then
    echo "PASS $1"; pass=$((pass + 1))
  else
    echo "FAIL $1 — output lacked /$2/" >&2
    tail -3 "$TMP/last.log" 2>/dev/null | sed 's/^/      /' >&2
    fail=$((fail + 1))
  fi
}

# --- assert_plan_artifacts ---
mkdir -p "$TMP/host/docs/specs/empty-spec"
check "plan-missing-files" 1 python3 "$ASSERT" "$TMP/host" empty-spec

SPEC="$TMP/host/docs/specs/ok-spec"
mkdir -p "$SPEC"
for f in VERSION.md contract.md tests.md plan.md run.md; do
  printf '# %s\n\nSubstantial placeholder content for gate test (%s).\n' "$f" "$f" >"$SPEC/$f"
done
check "plan-complete" 0 python3 "$ASSERT" "$TMP/host" ok-spec

# --- the wave gate: an Oracle replay, not a hand-written attestation ------------
# What was here: 13 probes for require-/record-conductor-falsify, a structured
# COMMAND + EXIT_CODE + VERDICT log the conductor typed by hand. That file was the manual
# form of "a command and its exit code", and ship.sh does it for real against the dispatch's
# own baseline. The replay itself is probed in selftest-ship (70 cases); what belongs here is
# that wish-orchestrate still refuses to wave on without one.
# Probed behaviourally below, once the wish fixture exists — grepping the script for the
# function's own name would pass on a stub, which is the static-slogan check this repo deleted.

fill_spec() {   # real Oracles derived from plan.md — a bodyless tests.md has none
  local spec_dir="$1" ids t
  for t in VERSION.md contract.md run.md; do
    printf '# %s\n\nenough content for placeholder gates.\n' "$t" >"$spec_dir/$t"
  done
  ids="$(grep -oE 'T-[0-9]{3}' "$spec_dir/plan.md" 2>/dev/null | sort -u | tr '\n' ' ')"
  [[ -n "$ids" ]] || ids="T-001"
  {
    printf '# Tests\n\n## 索引\n\n| ID | R |\n|---|---|\n'
    for t in $ids; do printf '| %s | R-001 |\n' "$t"; done
    for t in $ids; do
      printf '\n## %s · probe\n\n### Given\n\n- fixture\n\n### When\n\n1. run\n\n' "$t"
      printf '### Then（Oracle）\n\n- offset=0 与 offset=1000 首行 id 不同\n\n'
      printf '### 自动化\n\n- 命令：`bash -c true`\n- 预期 Evidence Kind：`unit`\n'
    done
  } >"$spec_dir/tests.md"
}

# --- wish-orchestrate: status + flock smoke (no codex) ---
HOST="$TMP/wishhost"
mkdir -p "$HOST/docs/specs/w1"
cat >"$HOST/docs/specs/w1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | Web：a | T-001 | src/a.ts | | |
| S2 | Web：b | T-002 | src/b.ts | S1 | |
EOF
fill_spec "$HOST/docs/specs/w1"
check "wish-status" 0 bash "$WISH" --cwd "$HOST" --spec w1 --status
check "wish-list" 0 bash "$WISH" --cwd "$HOST" --spec w1 --list
check "wish-pack-only" 0 bash "$WISH" --cwd "$HOST" --spec w1 --pack-only --slice S1

# Idempotency: mark S1 passed in state, pack-only still ok; dry-run skips passed
LOGW="$HOST/.codex-dispatch-logs"
mkdir -p "$LOGW"
cat >"$LOGW/wish-state-w1.env" <<'EOF'
AWAITING_FALSIFY=0
LAST_RUN_ID=
LAST_SLICE=
PASSED_SLICES='S1'
CORRELATION_ID=w1-test
SPEC_ID=w1
EOF
check "wish-dry-skip-passed" 0 bash "$WISH" --cwd "$HOST" --spec w1 --dry-run --slice S1

# The wave gate: a dispatch awaiting its replay may not wave on. Behavioural, not a grep —
# it drives wish-orchestrate with the awaiting flag set and no meta to replay against.
wave_state() {   # $1 = the awaiting variable name to write
  cat >"$LOGW/wish-state-w1.env" <<EOF
$1=1
LAST_RUN_ID=missingrun
LAST_RUN_IDS='missingrun'
LAST_SLICE=S1
LAST_DISPATCH=''
PASSED_SLICES=''
PASSED_UNITS=''
CORRELATION_ID=w1-test
SPEC_ID=w1
EOF
}
wave_state AWAITING_REPLAY
check "wave-gate-blocks-without-replay" 2 bash "$WISH" --cwd "$HOST" --spec w1 --dry-run --slice S2
saw_gates "wave-gate-names-missing-meta" 'no dispatch meta for missingrun'
# A wave dispatched before the rename wrote the old variable; dropping the alias would
# retire the gate for exactly those in-flight waves.
wave_state AWAITING_FALSIFY
check "wave-gate-legacy-state-blocks" 2 bash "$WISH" --cwd "$HOST" --spec w1 --dry-run --slice S2
wave_state AWAITING_REPLAY
check "wave-gate-skip-is-opt-in" 0 env SKIP_REPLAY_GATE=1 \
  bash "$WISH" --cwd "$HOST" --spec w1 --dry-run --slice S2
rm -f "$LOGW/wish-state-w1.env"
cat >"$LOGW/wish-state-w1.env" <<'EOF'
AWAITING_REPLAY=0
LAST_RUN_ID=
LAST_SLICE=
PASSED_SLICES='S1'
CORRELATION_ID=w1-test
SPEC_ID=w1
EOF

PACK_PY="$ROOT/skills/dispatch-codex/scripts/build_context_pack.py"
DETECT="$ROOT/skills/dispatch-codex/scripts/detect_compact.py"

HOSTM="$TMP/mergehost"
mkdir -p "$HOSTM/docs/specs/m1" "$HOSTM/src"
echo 'x' >"$HOSTM/src/foo.ts"
cat >"$HOSTM/docs/specs/m1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/foo.ts | | oracle:unit |
| S2 | b | T-002 | src/foo.ts | S1 | oracle:unit |
| S3 | c | T-003 | src/foo.ts | S1 | oracle:unit |
EOF
fill_spec "$HOSTM/docs/specs/m1"
# Three slices, one file. The packer used to merge them into a single 272K unit; now they stay
# three dispatch units and the edit lock puts each in its own wave — dispatching two of them in
# parallel would have their worktrees collide on src/foo.ts at merge.
assert_same_file_serial() {
  python3 "$PACK_PY" --waves "$HOSTM" m1 --parallel 3 \
    | python3 -c 'import json,sys; w=json.load(sys.stdin)["waves"]; assert [len(x) for x in w]==[1,1,1], w'
}
check "waves-same-file-serialised" 0 assert_same_file_serial

HOSTP="$TMP/parhost"
mkdir -p "$HOSTP/docs/specs/p1"
mkdir -p "$HOSTP/modules/track/collection/vrl" "$HOSTP/infra/postgres/init"
echo 'a' >"$HOSTP/modules/track/collection/vrl/sa.vrl"
echo 'b' >"$HOSTP/infra/postgres/init/01.sql"
cat >"$HOSTP/docs/specs/p1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | coll | T-001 | modules/track/collection/vrl/sa.vrl | | oracle:unit |
| S2 | pg | T-002 | infra/postgres/init/01.sql | | oracle:unit |
EOF
fill_spec "$HOSTP/docs/specs/p1"
assert_parallel() {
  python3 "$PACK_PY" --waves "$HOSTP" p1 --parallel 2 \
    | python3 -c 'import json,sys; w=json.load(sys.stdin); assert set(w["waves"][0])=={"S1","S2"}, w'
}
check "waves-independent-parallel" 0 assert_parallel

# Dependency order, isolated from the edit lock. It has to be a TRANSITIVE chain: for a direct
# dependency the lock's own "does this wave contain something I depend on" test already keeps
# the pair apart, so a two-slice probe stays green with the readiness filter deleted. S3 -> S2
# -> S1 on three different files is what the readiness filter alone decides.
HOSTD="$TMP/dephost"
mkdir -p "$HOSTD/docs/specs/d1" "$HOSTD/src"
echo a >"$HOSTD/src/one.ts"; echo b >"$HOSTD/src/two.ts"; echo c >"$HOSTD/src/three.ts"
cat >"$HOSTD/docs/specs/d1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/one.ts | | oracle:unit |
| S2 | b | T-002 | src/two.ts | S1 | oracle:unit |
| S3 | c | T-003 | src/three.ts | S2 | oracle:unit |
EOF
fill_spec "$HOSTD/docs/specs/d1"
assert_dep_order() {
  python3 "$PACK_PY" --waves "$HOSTD" d1 --parallel 3 \
    | python3 -c 'import json,sys; w=json.load(sys.stdin)["waves"]; assert w==[["S1"],["S2"],["S3"]], w'
}
check "waves-transitive-dependency-order" 0 assert_dep_order

HOSTL="$TMP/labhost"
mkdir -p "$HOSTL/docs/specs/l1" "$HOSTL/src/a" "$HOSTL/src/b"
echo 'a' >"$HOSTL/src/a/x.ts"
echo 'b' >"$HOSTL/src/b/y.ts"
cat >"$HOSTL/docs/specs/l1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a/x.ts | | oracle:lab claims:kind-datagate |
| S2 | b | T-002 | src/b/y.ts | | oracle:lab claims:kind-datagate |
EOF
fill_spec "$HOSTL/docs/specs/l1"
# The verify_waves half of the old scheduler, which serialised slices sharing a `claims:` lab
# resource, is gone rather than ported: grep found exactly one consumer — this probe. It was
# computed on every run and no dispatch path ever read it, so it scheduled nothing. If lab
# contention needs serialising, it needs a dispatch path first.

# --- action counting replaces the token peak estimate --------------------------
# 720 real sessions: <=50 agent actions -> 3% compacted, 51-200 -> 64%, 200+ -> 100%. The
# estimator this replaces predicted a peak that 342 codex_exec sessions never crossed.
mk_actions() {   # $1 = count, $2 = out path
  python3 - "$1" "$2" <<'ACT_PY'
import json, sys
n, out = int(sys.argv[1]), sys.argv[2]
rows = ['{"type":"turn.started"}']
rows += [json.dumps({"type": "item.completed", "item": {"type": "command_execution"}})
         for _ in range(n)]
rows.append('{"type":"turn.completed"}')
open(out, "w", encoding="utf-8").write("\n".join(rows) + "\n")
ACT_PY
}
mk_actions 160 "$TMP/acts-160.jsonl"
mk_actions 10 "$TMP/acts-10.jsonl"
count_is() { python3 "$DETECT" --require-turn "$2" | grep -q "\"actions\": $1,"; }
check "detect-counts-actions" 0 count_is 160 "$TMP/acts-160.jsonl"
zone_is() { python3 "$DETECT" --require-turn "$2" | grep -q "\"action_zone\": \"$1\""; }
check "detect-action-zone-safe" 0 zone_is safe "$TMP/acts-10.jsonl"
check "detect-action-zone-risky" 0 zone_is risky "$TMP/acts-160.jsonl"
# exit 3, not 1: the turn finished, so this is a unit that should have been split rather than
# a failed dispatch, and the two must not be reported as the same thing.
check "detect-action-budget-exit3" 3 \
  python3 "$DETECT" --require-turn --max-actions 150 "$TMP/acts-160.jsonl"
check "detect-action-budget-under" 0 \
  python3 "$DETECT" --require-turn --max-actions 150 "$TMP/acts-10.jsonl"

echo '{"type":"item","item":{"type":"agent_message","text":"ok"}}' >"$TMP/clean.jsonl"
check "detect-compact-clean" 0 python3 "$DETECT" "$TMP/clean.jsonl"
echo '{"type":"compaction","message":"auto_compact ran"}' >"$TMP/compact.jsonl"
check "detect-compact-hit" 1 python3 "$DETECT" "$TMP/compact.jsonl"
printf '%s\n' '{"type":"turn.started"}' '{"type":"turn.completed","usage":{"input_tokens":6395729,"cached_input_tokens":6207488}}' >"$TMP/usage.jsonl"
check "detect-usage-not-window" 0 python3 "$DETECT" --require-turn "$TMP/usage.jsonl"
echo '{"type":"turn.started"}' >"$TMP/no-turn.jsonl"
check "detect-require-turn-missing" 1 python3 "$DETECT" --require-turn "$TMP/no-turn.jsonl"
# spec text mentioning compact must not trip
printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution","command":"cat plan.md # auto-compact threshold"}}' '{"type":"turn.completed","usage":{"input_tokens":100}}' >"$TMP/false-compact.jsonl"
check "detect-false-compact-in-dump" 0 python3 "$DETECT" --require-turn "$TMP/false-compact.jsonl"

check "wish-units-list" 0 bash "$WISH" --cwd "$HOSTM" --spec m1 --units
check "wish-dry-merged-unit" 0 bash "$WISH" --cwd "$HOSTM" --spec m1 --dry-run
check "wish-dry-parallel-wave" 0 bash "$WISH" --cwd "$HOSTP" --spec p1 --dry-run --parallel 2

# --- the dispatch payload must carry the Oracle body, not its id ---------------
# Before: `Oracle ids: T-001, T-002` plus "Run the unit-relevant checks/tests"
# (implementer picks its own judge) and "or N/A · reason" (a written-in escape hatch).
FIX="$ROOT/skills/dispatch-codex/fixtures/live-relay"
PACKOUT="$TMP/pack-oracle.txt"
if python3 "$ROOT/skills/dispatch-codex/scripts/build_context_pack.py" "$FIX" live-relay S1 \
    >"$PACKOUT" 2>/dev/null; then
  check "pack-carries-command" 0 grep -qF -- 'python3 -m pytest tests/test_token.py' "$PACKOUT"
  check "pack-carries-then" 0 grep -q -- 'then:' "$PACKOUT"
  check "pack-drops-oracle-ids-only" 1 grep -q -- '^Oracle ids:' "$PACKOUT"
  check "pack-drops-self-chosen-tests" 1 grep -q -- 'Run the unit-relevant checks/tests' "$PACKOUT"
  check "pack-drops-na-escape-hatch" 1 grep -qF -- 'or N/A · reason' "$PACKOUT"
  check "pack-demands-runner-replay" 0 grep -q -- 'replays them' "$PACKOUT"
else
  echo "FAIL pack-carries-command — build_context_pack.py failed on the fixture" >&2
  fail=$((fail + 1))
fi

# --- the dispatch throat refuses an Oracle the runner cannot execute -----------
# Rendering "同 T-001" into a block labelled "frozen Oracle, the runner replays this"
# would be the same lie as the old `Oracle ids:` payload, one layer down.
mkfix() {  # mkfix <dir> <sed-expr-on-T-001-command>
  rm -rf "$1"; cp -r "$FIX" "$1"
  python3 - "$1/docs/specs/live-relay/tests.md" "$2" <<'PYX'
import re, sys
p, repl = sys.argv[1], sys.argv[2]
t = open(p, encoding="utf-8").read()
i, j = t.index("## T-001"), t.index("## T-002")
open(p, "w", encoding="utf-8").write(
    t[:i] + re.sub(r"(?m)^(\s*-\s*命令[：:]).*$", r"\1 " + repl, t[i:j], count=1) + t[j:])
PYX
}
PACKBIN="$ROOT/skills/dispatch-codex/scripts/build_context_pack.py"
mkfix "$TMP/fix-ref" "同 T-002。"
check "pack-refuses-referential" 2 python3 "$PACKBIN" "$TMP/fix-ref" live-relay S1
mkfix "$TMP/fix-noop" '`true`'
check "pack-refuses-noop" 2 python3 "$PACKBIN" "$TMP/fix-noop" live-relay S1
rm -rf "$TMP/fix-vis"; cp -r "$FIX" "$TMP/fix-vis"
sed -i 's/| R-001 | 签名 token/| R-001 | 文案与移动端可读：签名 token/' \
  "$TMP/fix-vis/docs/specs/live-relay/contract.md"
check "pack-refuses-visible-unit-only" 2 python3 "$PACKBIN" "$TMP/fix-vis" live-relay S1
# …but a declared human oracle closes that same gap: `manual-only` must not be refused
# where `human` is accepted, or the template's escape hatch is a lie.
mkfix "$TMP/fix-vis-h" '`manual-only`'
sed -i 's/| R-001 | 签名 token/| R-001 | 文案与移动端可读：签名 token/' \
  "$TMP/fix-vis-h/docs/specs/live-relay/contract.md"
check "pack-visible-closed-by-manual-only" 0 python3 "$PACKBIN" "$TMP/fix-vis-h" live-relay S1
# …and so does a declared browser-job Evidence Kind: the throat must not refuse a Spec
# that `check_spec --closing` accepts, or a legitimate declaration blocks the dispatch.
mkfix "$TMP/fix-vis-k" '`npx vitest run a.test.ts`'
sed -i 's/| R-001 | 签名 token/| R-001 | 文案与移动端可读：签名 token/' \
  "$TMP/fix-vis-k/docs/specs/live-relay/contract.md"
sed -i 's/预期 Evidence Kind：`unit`/预期 Evidence Kind：`browser-job`/g' \
  "$TMP/fix-vis-k/docs/specs/live-relay/tests.md"
check "pack-visible-closed-by-declared-kind" 0 python3 "$PACKBIN" "$TMP/fix-vis-k" live-relay S1
# The shipped tests.md template says to write `manual-only`, not `human`. If the throat
# refuses the template's own vocabulary, that is this gate's bug: 3 live oracles say it.
mkfix "$TMP/fix-manual" '`manual-only`'
check "pack-accepts-manual-only" 0 python3 "$PACKBIN" "$TMP/fix-manual" live-relay S1
python3 "$PACKBIN" "$TMP/fix-manual" live-relay S1 >"$TMP/pack-manual.txt" 2>/dev/null || true
check "pack-manual-only-out-of-replay-set" 0 grep -q '人工判定' "$TMP/pack-manual.txt"

mkfix "$TMP/fix-human" '`human`'
if python3 "$PACKBIN" "$TMP/fix-human" live-relay S1 >"$TMP/pack-human.txt" 2>/dev/null; then
  check "pack-human-emits" 0 grep -q '人工判定' "$TMP/pack-human.txt"
  check "pack-human-out-of-replay-set" 1 grep -q 'T-001, T-002 pass when' "$TMP/pack-human.txt"
else
  echo "FAIL pack-human-emits — a human oracle must still produce a pack" >&2
  fail=$((fail + 1))
fi

# --- auth block present in dispatcher ---
check "auth-block-in-dispatch" 0 \
  grep -q "CLI dispatch authorization" "$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"

# --- attestation doc exists ---
check "oracle-replay-runner-present" 0 \
  test -f "$ROOT/skills/dispatch-codex/scripts/ship.sh"

echo "--- codex lifecycle (mock CLI, isolated tmp; no host repos) ---"
bash "$ROOT/skills/dispatch-codex/scripts/selftest-codex-lifecycle.sh"

echo "--- selftest-gates: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
