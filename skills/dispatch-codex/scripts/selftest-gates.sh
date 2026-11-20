#!/usr/bin/env bash
# Offline gates for dispatch-codex hard doors (no Codex required).
# Run from plugin root: bash skills/dispatch-codex/scripts/selftest-gates.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSERT="$ROOT/skills/dispatch-codex/scripts/assert_plan_artifacts.py"
ELIGIBLE="$ROOT/skills/dispatch-codex/scripts/assert_codex_eligible.py"
DISPATCH="$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"
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

# A directory allowlist overlaps every file under it. String equality said `src/` and
# `src/a.ts` share nothing, so they went out in the same wave and the worktrees could conflict
# on merge. Lower-case deps used to read as an unknown slice, which this scheduler treats as
# unblocked — so the dependent was scheduled alongside what it depends on.
HOSTX="$TMP/domainhost"
mkdir -p "$HOSTX/docs/specs/x1" "$HOSTX/src" "$HOSTX/lib"
echo a >"$HOSTX/src/a.ts"; echo b >"$HOSTX/lib/x.ts"
cat >"$HOSTX/docs/specs/x1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | dir | T-001 | src/ | | oracle:unit |
| S2 | file | T-002 | src/a.ts | | oracle:unit |
| S3 | dep | T-003 | lib/x.ts | s1 | oracle:unit |
EOF
fill_spec "$HOSTX/docs/specs/x1"
assert_domain() {
  python3 "$PACK_PY" --waves "$HOSTX" x1 --parallel 3 \
    | python3 -c 'import json,sys
w = json.load(sys.stdin)["waves"]
assert w[0] == ["S1"], w                       # dir vs file must not share a wave
assert "S3" not in w[0], w                     # lower-case dep still blocks
assert sorted(sum(w, [])) == ["S1","S2","S3"], w'
}
check "waves-path-domain-and-case" 0 assert_domain

HOSTY="$TMP/duphost"
mkdir -p "$HOSTY/docs/specs/y1"
cat >"$HOSTY/docs/specs/y1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
| S1 | dup | T-002 | src/b.ts | | oracle:unit |
EOF
fill_spec "$HOSTY/docs/specs/y1"
# Two rows with one id collapsed through the done set: one wave came out and the other row's
# work vanished, while dependents were scheduled as if both had run.
check "waves-duplicate-slice-id-refused" 2 \
  python3 "$PACK_PY" --waves "$HOSTY" y1 --parallel 2
saw_gates "waves-names-duplicate-id" 'duplicate slice ids'

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

# --- Codex boundary (eligible vs refuse) ---
check "eligible-file-unit-oracle" 0 python3 "$ELIGIBLE" "$HOSTM" m1 S1
check "ineligible-directory-allowlist" 2 python3 "$ELIGIBLE" "$HOSTX" x1 S1
saw_gates "ineligible-dir-reason" 'directory-allowlist'
check "ineligible-oracle-lab" 2 python3 "$ELIGIBLE" "$HOSTL" l1 S1
saw_gates "ineligible-lab-reason" 'oracle-human-or-lab'

HOSTUI="$TMP/uihost"
mkdir -p "$HOSTUI/docs/specs/u1" "$HOSTUI/src"
echo 'x' >"$HOSTUI/src/App.tsx"
cat >"$HOSTUI/docs/specs/u1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | Web page | T-001 | src/App.tsx | | oracle:unit page_kind: list |
EOF
fill_spec "$HOSTUI/docs/specs/u1"
check "ineligible-ui-path" 2 python3 "$ELIGIBLE" "$HOSTUI" u1 S1
saw_gates "ineligible-ui-reason" 'ui-'

HOSTH="$TMP/humhost"
mkdir -p "$HOSTH/docs/specs/h1" "$HOSTH/src"
echo 'x' >"$HOSTH/src/a.ts"
cat >"$HOSTH/docs/specs/h1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:human |
EOF
fill_spec "$HOSTH/docs/specs/h1"
# fill_spec writes a machine command; the note still marks human/lab-style work.
check "ineligible-note-human" 2 python3 "$ELIGIBLE" "$HOSTH" h1 S1
saw_gates "ineligible-human-reason" 'oracle-human-or-lab'

HOSTE="$TMP/emptycmd"
mkdir -p "$HOSTE/docs/specs/e1" "$HOSTE/src"
echo 'x' >"$HOSTE/src/a.ts"
cat >"$HOSTE/docs/specs/e1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
EOF
for t in VERSION.md contract.md run.md; do
  printf '# %s\n\nenough content for placeholder gates.\n' "$t" >"$HOSTE/docs/specs/e1/$t"
done
cat >"$HOSTE/docs/specs/e1/tests.md" <<'EOF'
# Tests

## 索引

| ID | R |
|---|---|
| T-001 | R-001 |

## T-001 · probe

### Given

- fixture

### When

1. run

### Then（Oracle）

- offset=0 与 offset=1000 首行 id 不同
EOF
check "ineligible-no-command" 2 python3 "$ELIGIBLE" "$HOSTE" e1 S1
saw_gates "ineligible-no-cmd-reason" 'oracle-invalid|no-machine-oracle'

check "plan-unit-refused" 2 bash "$DISPATCH" --cwd "$HOSTM" --unit plan --spec m1 -- "noop"
saw_gates "plan-unit-names-boundary" 'Codex boundary'

check "dispatch-refuses-dir-slice" 2 env SKIP_SPEC_CHECK=1 \
  bash "$DISPATCH" --cwd "$HOSTX" --unit build --spec x1 --slice S1 -- "SLICE_ID=S1"
saw_gates "dispatch-dir-names-boundary" 'Codex boundary'

HOSTMIX="$TMP/mixhost"
mkdir -p "$HOSTMIX/docs/specs/mix1" "$HOSTMIX/src"
echo a >"$HOSTMIX/src/ok.ts"
echo b >"$HOSTMIX/src/App.tsx"
cat >"$HOSTMIX/docs/specs/mix1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | api | T-001 | src/ok.ts | | oracle:unit |
| S2 | ui | T-002 | src/App.tsx | | oracle:unit page_kind: list |
EOF
fill_spec "$HOSTMIX/docs/specs/mix1"
check "wish-mixed-wave-conductor" 2 bash "$WISH" --cwd "$HOSTMIX" --spec mix1 --dry-run --parallel 2
saw_gates "wish-names-conductor-required" 'CONDUCTOR_REQUIRED'

check "check-spec-executor-split" 0 python3 -c '
import importlib.util, sys
from pathlib import Path
root, ui_host, el_host = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
spec = importlib.util.spec_from_file_location("cs", root / "skills/spec/scripts/check_spec.py")
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)
ui = ui_host / "docs/specs/u1"
ok, why = cs.dispatch_evidence_valid("executor: conductor\n", ui)
assert ok, why
ok2, why2 = cs.dispatch_evidence_valid("结论：实现完成\n", ui)
assert not ok2 and "conductor" in why2, why2
el = el_host / "docs/specs/m1"
ok3, why3 = cs.dispatch_evidence_valid("executor: conductor\n", el)
assert not ok3 and "eligible" in why3, why3
ok4, why4 = cs.dispatch_evidence_valid("override: 用户要求自写\n", el)
assert ok4, why4
' "$ROOT" "$HOSTUI" "$HOSTM"

# --- auth block present in dispatcher ---
check "auth-block-in-dispatch" 0 \
  grep -q "CLI dispatch authorization" "$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"

# --- attestation doc exists ---
check "oracle-replay-runner-present" 0 \
  test -f "$ROOT/skills/dispatch-codex/scripts/ship.sh"

# --- conductor slices need no allowlist; extensionless known files are files ---
# Regression: a real run died with "incomplete allowlist on slices: S0 S3" for slices that
# were never going to be dispatched (--dry-run skipped the check, so it only showed live).
CHOST="$TMP/conductorhost"
mkdir -p "$CHOST/docs/specs/c1"
cat >"$CHOST/docs/specs/c1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
|---|---|---|---|---|---|
| S0 | 指挥侧复验 | — | — | | executor: conductor |
| S1 | 删 a | T-001 | src/a.py | S0 | oracle:unit |
| S2 | 指挥侧回归 | — | — | S1 | executor: conductor |
EOF
fill_spec "$CHOST/docs/specs/c1"
check "waves-conductor-slices-not-incomplete" 0 \
  bash -c 'python3 "$1" "$2" c1 --waves 2>/dev/null | python3 -c "import sys,json; sys.exit(1 if json.load(sys.stdin)[\"incomplete_allowlist\"] else 0)"' _ \
    "$ROOT/skills/dispatch-codex/scripts/build_context_pack.py" "$CHOST"
check "allowlist-makefile-is-a-file" 0 \
  python3 -c "
import importlib.util,sys
s=importlib.util.spec_from_file_location('e','$ELIGIBLE');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
sys.exit(0 if (not m.is_directory_allowlist('Makefile')) and m.is_directory_allowlist('src') and m.is_directory_allowlist('scripts/') else 1)"

# --- Audit and explicit user override: offline mock CLI ---
mkdir -p "$TMP/audit-bin" "$TMP/audit-host"
cat >"$TMP/audit-bin/codex" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$MOCK_ARGS"
cat >"$MOCK_PROMPT"
case "${MOCK_AUDIT_MODE:-complete}" in
  complete) echo '{"type":"turn.completed"}' ;;
  no-turn) echo '{"type":"turn.started"}' ;;
  quota) echo '{"type":"error","message":"usage limit reached; try again at 10:00"}'; exit 1 ;;
esac
MOCK
chmod +x "$TMP/audit-bin/codex"
audit_dispatch() {
  env -u CODEX_DISPATCH_SANDBOX -u CODEX_DISPATCH_TIMEOUT_SEC \
    -u CODEX_DISPATCH_SPEC -u CODEX_DISPATCH_SLICE \
    PATH="$TMP/audit-bin:$PATH" MOCK_ARGS="$TMP/audit-args" MOCK_PROMPT="$TMP/audit-prompt" \
    "$@"
}
check "audit-no-spec-defaults" 0 audit_dispatch bash "$DISPATCH" \
  --cwd "$TMP/audit-host" --unit audit --log-dir "$TMP/audit-log" -- inspect
check "audit-cli-read-only" 0 grep -qx 'read-only' "$TMP/audit-args"
check "audit-prompt-read-only" 0 grep -q 'read-only audit/inventory/check only' "$TMP/audit-prompt"
audit_meta() { grep -qx "$1" "$TMP"/audit-log/*.meta.txt; }
check "audit-meta-read-only" 0 audit_meta sandbox=read-only
check "audit-default-timeout" 0 audit_meta timeout_sec=1200
check "audit-run-finished" 0 audit_meta run_state=finished
for mode in workspace-write danger-full-access; do
  check "audit-reject-cli-$mode" 2 audit_dispatch bash "$DISPATCH" \
    --cwd "$TMP/audit-host" --unit audit --sandbox "$mode" -- inspect
  saw_gates "audit-cli-refusal-$mode" 'audit requires --sandbox read-only'
  check "audit-reject-env-$mode" 2 audit_dispatch env CODEX_DISPATCH_SANDBOX="$mode" \
    bash "$DISPATCH" --cwd "$TMP/audit-host" --unit audit -- inspect
  saw_gates "audit-env-refusal-$mode" 'audit requires CODEX_DISPATCH_SANDBOX=read-only'
done
check "audit-timeout-override" 0 audit_dispatch bash "$DISPATCH" \
  --cwd "$TMP/audit-host" --unit audit --sandbox read-only --timeout 7 \
  --log-dir "$TMP/audit-timeout-log" -- inspect
check "audit-timeout-meta" 0 grep -qx timeout_sec=7 "$TMP"/audit-timeout-log/*.meta.txt
check "audit-requires-turn" 2 audit_dispatch env MOCK_AUDIT_MODE=no-turn bash "$DISPATCH" \
  --cwd "$TMP/audit-host" --unit audit --log-dir "$TMP/audit-noturn-log" -- inspect
saw_gates "audit-turn-refusal" 'did not finish cleanly'
check "audit-quota-class" 75 audit_dispatch env MOCK_AUDIT_MODE=quota bash "$DISPATCH" \
  --cwd "$TMP/audit-host" --unit audit --log-dir "$TMP/audit-quota-log" -- inspect
check "audit-quota-meta" 0 grep -qx failure_class=quota "$TMP"/audit-quota-log/*.meta.txt
check "build-no-spec-still-refused" 2 audit_dispatch bash "$DISPATCH" \
  --cwd "$TMP/audit-host" --unit build --slice S1 -- inspect
saw_gates "build-no-spec-reason" 'build requires --spec'
check "override-keeps-spec-gate" 2 audit_dispatch env CODEX_DISPATCH_OVERRIDE=user-command \
  bash "$DISPATCH" --cwd "$TMP/audit-host" --unit build --slice S1 -- inspect
saw_gates "override-spec-reason" 'build requires --spec'
check "override-bypasses-eligible" 0 audit_dispatch env CODEX_DISPATCH_OVERRIDE=user-command \
  SKIP_SPEC_CHECK=1 bash "$DISPATCH" --cwd "$HOSTX" --unit build --spec x1 --slice S1 \
  --log-dir "$TMP/override-log" -- inspect
check "override-meta" 0 grep -qx override=user-command "$TMP"/override-log/*.meta.txt

echo "--- codex lifecycle (mock CLI, isolated tmp; no host repos) ---"
bash "$ROOT/skills/dispatch-codex/scripts/selftest-codex-lifecycle.sh"

echo "--- selftest-gates: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
