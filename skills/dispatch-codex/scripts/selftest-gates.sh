#!/usr/bin/env bash
# Offline gates for dispatch-codex hard doors (no Codex required).
# Run from plugin root: bash skills/dispatch-codex/scripts/selftest-gates.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSERT="$ROOT/skills/dispatch-codex/scripts/assert_plan_artifacts.py"
REQUIRE="$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh"
RECORD="$ROOT/skills/dispatch-codex/scripts/record-conductor-falsify.sh"
WISH="$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  local name="$1" expect="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
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

# --- assert_plan_artifacts ---
mkdir -p "$TMP/host/docs/specs/empty-spec"
check "plan-missing-files" 1 python3 "$ASSERT" "$TMP/host" empty-spec

SPEC="$TMP/host/docs/specs/ok-spec"
mkdir -p "$SPEC"
for f in VERSION.md contract.md tests.md plan.md run.md; do
  printf '# %s\n\nSubstantial placeholder content for gate test (%s).\n' "$f" "$f" >"$SPEC/$f"
done
check "plan-complete" 0 python3 "$ASSERT" "$TMP/host" ok-spec

# --- require-conductor-falsify: unstructured / structured ---
LOG="$TMP/logs"
mkdir -p "$LOG"
echo "ran some tests" >"$LOG/run1_falsify.log"
check "falsify-no-verdict" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run1

echo "VERDICT: S1 FAIL" >"$LOG/run2_falsify.log"
check "falsify-verdict-fail-unstructured" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run2

# Verdict PASS alone is no longer enough
echo "VERDICT: S1 PASS (conductor re-ran)" >"$LOG/run3_falsify.log"
check "falsify-verdict-pass-unstructured" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run3

# Structured PASS
cat >"$LOG/run4_falsify.log" <<'EOF'
COMMAND: echo probe
EXIT_CODE: 0
SLICE: S1
RUN_ID: run4
VERDICT: S1 PASS
EOF
check "falsify-structured-pass" 0 bash "$REQUIRE" --log-dir "$LOG" --run-id run4

# PASS with non-zero EXIT_CODE
cat >"$LOG/run5_falsify.log" <<'EOF'
COMMAND: false
EXIT_CODE: 1
VERDICT: S1 PASS
EOF
check "falsify-pass-nonzero-exit" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run5

# ARTIFACT without hash
cat >"$LOG/run6_falsify.log" <<'EOF'
COMMAND: echo x
EXIT_CODE: 0
ARTIFACT: /tmp/nope
VERDICT: S1 PASS
EOF
check "falsify-artifact-no-hash" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id run6

SKIP_FALSIFY_VERDICT=1 check "falsify-skip-verdict-env" 0 \
  bash "$REQUIRE" --log-dir "$LOG" --run-id run1

SKIP_STRUCTURED_FALSIFY=1 check "falsify-skip-structured-env" 0 \
  bash "$REQUIRE" --log-dir "$LOG" --run-id run3

# --- record-conductor-falsify ---
check "record-falsify-success" 0 \
  bash "$RECORD" --log-dir "$LOG" --run-id rec1 --slice S1 -- echo probe-ok
check "require-after-record" 0 bash "$REQUIRE" --log-dir "$LOG" --run-id rec1
bash "$RECORD" --log-dir "$LOG" --run-id rec_noop --slice S1 -- true >/dev/null || true
check "require-noop-command" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id rec_noop
check "record-falsify-fail-cmd" 1 \
  bash "$RECORD" --log-dir "$LOG" --run-id rec2 --slice S1 -- false
check "require-after-record-fail" 1 bash "$REQUIRE" --log-dir "$LOG" --run-id rec2

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

PACK_UNITS="$ROOT/skills/dispatch-codex/scripts/pack_dispatch_units.py"
SCHEDULE="$ROOT/skills/dispatch-codex/scripts/schedule_waves.py"
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
assert_merge() {
  python3 "$PACK_UNITS" "$HOSTM" m1 --json | python3 -c 'import json,sys; g=json.load(sys.stdin); assert len(g["units"])==1, g; assert g["units"][0]["slices"]==["S1","S2","S3"], g'
}
check "pack-merge-same-writes" 0 assert_merge

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
  python3 "$SCHEDULE" --host "$HOSTP" --spec p1 --edit-parallel 2 | python3 -c 'import json,sys; w=json.load(sys.stdin); assert set(w["edit_waves"][0])=={"D1","D2"}, w'
}
check "schedule-edit-parallel" 0 assert_parallel

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
assert_lab_serial() {
  python3 "$SCHEDULE" --host "$HOSTL" --spec l1 --edit-parallel 2 | python3 -c 'import json,sys; w=json.load(sys.stdin); assert all(len(v)==1 for v in w["verify_waves"]), w'
}
check "schedule-verify-serial-lab" 0 assert_lab_serial

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
check "falsify-attestation-doc" 0 \
  test -f "$ROOT/skills/dispatch-codex/references/falsify-attestation.md"

echo "--- codex lifecycle (mock CLI, isolated tmp; no host repos) ---"
bash "$ROOT/skills/dispatch-codex/scripts/selftest-codex-lifecycle.sh"

echo "--- selftest-gates: pass=$pass fail=$fail ---"
[[ "$fail" -eq 0 ]]
