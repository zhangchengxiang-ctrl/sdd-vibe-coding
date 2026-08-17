#!/usr/bin/env bash
# Isolated Codex lifecycle tests (mock CLI only). Never touches sibling host repos.
# Run: bash skills/dispatch-codex/scripts/selftest-codex-lifecycle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DISPATCH="$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"
WISH="$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh"
DETECT="$ROOT/skills/dispatch-codex/scripts/detect_compact.py"
PACK_UNITS="$ROOT/skills/dispatch-codex/scripts/pack_dispatch_units.py"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sdd-codex-life.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

BIN="$TMP/bin"
MOCK_DIR="$TMP/mock-state"
mkdir -p "$BIN" "$MOCK_DIR"
export MOCK_CODEX_DIR="$MOCK_DIR"
export SKIP_SPEC_CHECK=1
export CODEX_DISPATCH_TIMEOUT_SEC=30

cat >"$BIN/codex" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
# Mock `codex exec` for plugin selftests. Honors MOCK_CODEX_MODE / SLEEP / DIR.
[[ "${1:-}" == "exec" ]] || { echo "mock-codex: expected exec, got: $*" >&2; exit 2; }
shift
out_last=""
json=0
cwd="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message) out_last="${2:-}"; shift 2 ;;
    --json) json=1; shift ;;
    -C) cwd="${2:-}"; shift 2 ;;
    -c|-m|-s|--timeout) shift 2 ;;
    --skip-git-repo-check) shift ;;
    *) shift ;;
  esac
done
prompt="$(cat || true)"
mkdir -p "${MOCK_CODEX_DIR:?}"
start_ns="$(date +%s%N)"
{
  echo "start_ns=$start_ns pid=$$ mode=${MOCK_CODEX_MODE:-complete} cwd=$cwd"
  echo "prompt_head=$(printf '%s' "$prompt" | head -c 120 | tr '\n' ' ')"
} >>"$MOCK_CODEX_DIR/invocations.log"

if [[ -n "${MOCK_EXPECT_RUN_ID_FILE:-}" ]]; then
  if [[ ! -s "$MOCK_EXPECT_RUN_ID_FILE" ]]; then
    echo "mock-codex: run-id-file missing at exec start: $MOCK_EXPECT_RUN_ID_FILE" >&2
    exit 3
  fi
  echo "saw_run_id=$(tr -d '[:space:]' <"$MOCK_EXPECT_RUN_ID_FILE")" >>"$MOCK_CODEX_DIR/invocations.log"
fi

# Refuse to run against anything outside the isolated tmp host.
case "$cwd" in
  "${MOCK_ALLOWED_CWD_PREFIX:-/__never__}"*) ;;
  *)
    echo "mock-codex: cwd outside isolated fixture: $cwd" >&2
    exit 4
    ;;
esac

sleep "${MOCK_CODEX_SLEEP:-0}"
mode="${MOCK_CODEX_MODE:-complete}"

emit_jsonl() {
  [[ "$json" == "1" ]] || return 0
  printf '%s\n' "$@"
}

case "$mode" in
  complete)
    emit_jsonl \
      '{"type":"thread.started","thread_id":"mock-thread"}' \
      '{"type":"turn.started"}' \
      '{"type":"item.started","item":{"id":"item_1","type":"command_execution"}}' \
      '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"sed -n 1,80p docs/specs/x/plan.md # auto-compact threshold 180K"}}' \
      '{"type":"item.completed","item":{"id":"item_2","type":"agent_message","text":"S1 done.\n\nEvidence in run.md."}}' \
      '{"type":"turn.completed","usage":{"input_tokens":6395729,"cached_input_tokens":6207488,"output_tokens":1200,"reasoning_output_tokens":400}}'
    if [[ -n "$out_last" ]]; then
      printf '%s\n' 'S1 done. Evidence in run.md.' >"$out_last"
    fi
    echo "end_ns=$(date +%s%N) pid=$$" >>"$MOCK_CODEX_DIR/invocations.log"
    exit 0
    ;;
  quota-decoy)
    # A *successful* turn whose agent text merely mentions the quota wording, plus a
    # command_execution echoing a file that contains it. Must NOT be read as quota.
    emit_jsonl \
      '{"type":"thread.started","thread_id":"mock-thread"}' \
      '{"type":"turn.started"}' \
      '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"grep -n usage codex-dispatch.sh","aggregated_output":"You have hit your usage limit. Visit … to purchase more credits or try again at Aug 8th, 2026 11:41 AM."}}' \
      '{"type":"item.completed","item":{"id":"item_2","type":"agent_message","text":"Documented the usage limit handling."}}' \
      '{"type":"turn.completed","usage":{"input_tokens":100,"output_tokens":10}}'
    if [[ -n "$out_last" ]]; then printf '%s\n' 'done' >"$out_last"; fi
    echo "end_ns=$(date +%s%N) pid=$$" >>"$MOCK_CODEX_DIR/invocations.log"
    exit 0
    ;;
  quota)
    # Verbatim shape of the real production failure: 6 of 75 dispatches died here
    # and were indistinguishable from "Codex could not do the work".
    emit_jsonl \
      '{"type":"thread.started","thread_id":"mock-thread"}' \
      '{"type":"turn.started"}' \
      '{"type":"error","message":"You'"'"'ve hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Aug 8th, 2026 11:41 AM."}' \
      '{"type":"turn.failed","error":{"message":"You'"'"'ve hit your usage limit."}}'
    echo "end_ns=$(date +%s%N) pid=$$" >>"$MOCK_CODEX_DIR/invocations.log"
    exit 1
    ;;
  no-turn)
    emit_jsonl \
      '{"type":"turn.started"}' \
      '{"type":"item.completed","item":{"type":"agent_message","text":"still going"}}'
    [[ -n "$out_last" ]] && printf '%s\n' 'partial' >"$out_last"
    echo "end_ns=$(date +%s%N) pid=$$" >>"$MOCK_CODEX_DIR/invocations.log"
    exit 0
    ;;
  compact)
    emit_jsonl \
      '{"type":"turn.started"}' \
      '{"type":"compaction","message":"auto_compact ran"}' \
      '{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":1}}'
    [[ -n "$out_last" ]] && printf '%s\n' 'compacted' >"$out_last"
    echo "end_ns=$(date +%s%N) pid=$$" >>"$MOCK_CODEX_DIR/invocations.log"
    exit 0
    ;;
  crash)
    emit_jsonl '{"type":"turn.started"}'
    echo "end_ns=$(date +%s%N) pid=$$" >>"$MOCK_CODEX_DIR/invocations.log"
    exit 1
    ;;
  *)
    echo "mock-codex: unknown MOCK_CODEX_MODE=$mode" >&2
    exit 2
    ;;
esac
MOCK
chmod +x "$BIN/codex"
export PATH="$BIN:$PATH"

if [[ "$(command -v codex)" != "$BIN/codex" ]]; then
  echo "FAIL mock-codex not first on PATH (got $(command -v codex))" >&2
  exit 1
fi

pass=0
fail=0
PASS() { echo "PASS  $1"; pass=$((pass + 1)); }
FAIL() { echo "FAIL  $1 — $2" >&2; fail=$((fail + 1)); }

fill_spec() {
  local spec_dir="$1"
  mkdir -p "$spec_dir"
  local f
  for f in VERSION.md contract.md run.md; do
    printf '# %s\n\nSubstantial placeholder content for isolated lifecycle (%s).\n' "$f" "$f" >"$spec_dir/$f"
  done
  # A tests.md with no T-xxx bodies carries no Oracle, and the dispatch throat refuses
  # that — correctly. Derive the ids from plan.md so every fixture gets real ones.
  local ids
  ids="$(grep -oE 'T-[0-9]{3}' "$spec_dir/plan.md" 2>/dev/null | sort -u | tr '\n' ' ')"
  [[ -n "$ids" ]] || ids="T-001"
  {
    printf '# Tests\n\n## 索引\n\n| ID | R |\n|---|---|\n'
    for t in $ids; do printf '| %s | R-001 |\n' "$t"; done
    for t in $ids; do
      printf '\n## %s · fixture\n\n### Given\n\n- fixture state\n\n### When\n\n1. run it\n\n' "$t"
      printf '### Then（Oracle）\n\n- offset=0 与 offset=1000 首行 id 不同\n\n'
      printf '### 自动化\n\n- 命令：`bash -c true`\n- 预期 Evidence Kind：`unit`\n'
    done
  } >"$spec_dir/tests.md"
}

# --- T1: run-id-file exists before exec; decoy meta cannot steal id ---
HOST1="$TMP/host-runid"
mkdir -p "$HOST1/docs/specs/cpx" "$HOST1/src"
echo 'export const x = 1' >"$HOST1/src/a.ts"
cat >"$HOST1/docs/specs/cpx/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
EOF
fill_spec "$HOST1/docs/specs/cpx"
LOG1="$HOST1/.codex-dispatch-logs"
mkdir -p "$LOG1"
# Poison: newer-looking leftover that old ls -t guesser could return
cat >"$LOG1/build_20991231T235959Z_999999.meta.txt" <<'EOF'
cwd=/poison
unit=build
spec=cpx
dispatch_id=D1
slice=S1
slices=S1
exit_status=0
run_id=POISON_DECOY
EOF
RID1="$TMP/run-id-D1.txt"
export MOCK_ALLOWED_CWD_PREFIX="$TMP"
export MOCK_CODEX_MODE=complete
export MOCK_CODEX_SLEEP=0
export MOCK_EXPECT_RUN_ID_FILE="$RID1"
rm -f "$RID1" "$MOCK_DIR/invocations.log"
set +e
bash "$DISPATCH" \
  --cwd "$HOST1" \
  --unit build \
  --spec cpx \
  --slice S1 \
  --dispatch-id D1 \
  --log-dir "$LOG1" \
  --run-id-file "$RID1" \
  --timeout 20 \
  -- \
  $'DISPATCH_ID=D1\nSLICE_IDS=S1\n## Goal\nfinish S1\n' \
  >"$TMP/t1.out" 2>"$TMP/t1.err"
st=$?
set -e
unset MOCK_EXPECT_RUN_ID_FILE
if [[ "$st" -ne 0 ]]; then
  FAIL "t1-dispatch-complete" "exit=$st stderr=$(head -c 400 "$TMP/t1.err" | tr '\n' ' ')"
else
  rid="$(tr -d '[:space:]' <"$RID1")"
  meta_rid="$(grep '^run_id=' "$LOG1/${rid}.meta.txt" | head -1 | cut -d= -f2-)"
  if [[ "$rid" == "POISON_DECOY" ]]; then
    FAIL "t1-run-id-not-decoy" "run-id-file leaked poison"
  elif [[ -z "$rid" || "$rid" != "$meta_rid" ]]; then
    FAIL "t1-run-id-matches-meta" "file=$rid meta=$meta_rid"
  elif ! grep -q 'saw_run_id=' "$MOCK_DIR/invocations.log"; then
    FAIL "t1-run-id-before-exec" "mock did not see run-id-file at start"
  elif [[ ! -s "$LOG1/${rid}.last.md" ]]; then
    FAIL "t1-last-message" "missing --output-last-message file"
  else
    python3 "$DETECT" --require-turn "$LOG1/${rid}.jsonl" >/dev/null \
      && PASS "t1-run-id-file+turn.completed+last.md" \
      || FAIL "t1-jsonl-turn" "detect_compact --require-turn failed"
  fi
fi

# --- T2: process exit 0 without turn.completed must fail ---
HOST2="$TMP/host-noturn"
mkdir -p "$HOST2/docs/specs/cpx" "$HOST2/src"
echo 'x' >"$HOST2/src/a.ts"
cat >"$HOST2/docs/specs/cpx/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
EOF
fill_spec "$HOST2/docs/specs/cpx"
export MOCK_CODEX_MODE=no-turn
set +e
bash "$DISPATCH" \
  --cwd "$HOST2" \
  --unit build \
  --spec cpx \
  --slice S1 \
  --dispatch-id D1 \
  --log-dir "$HOST2/.codex-dispatch-logs" \
  --timeout 20 \
  -- \
  $'DISPATCH_ID=D1\nSLICE_IDS=S1\n## Goal\nfinish S1\n' \
  >"$TMP/t2.out" 2>"$TMP/t2.err"
st=$?
set -e
if [[ "$st" -eq 2 ]] && grep -q 'did not finish cleanly\|turn.completed' "$TMP/t2.err"; then
  PASS "t2-no-turn.completed-rejected"
else
  FAIL "t2-no-turn.completed-rejected" "exit=$st want=2 stderr=$(head -c 300 "$TMP/t2.err" | tr '\n' ' ')"
fi

# --- T3: explicit compact event rejected even with turn.completed ---
HOST3="$TMP/host-compact"
mkdir -p "$HOST3/docs/specs/cpx" "$HOST3/src"
echo 'x' >"$HOST3/src/a.ts"
cat >"$HOST3/docs/specs/cpx/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
EOF
fill_spec "$HOST3/docs/specs/cpx"
export MOCK_CODEX_MODE=compact
set +e
bash "$DISPATCH" \
  --cwd "$HOST3" \
  --unit build \
  --spec cpx \
  --slice S1 \
  --dispatch-id D1 \
  --log-dir "$HOST3/.codex-dispatch-logs" \
  --timeout 20 \
  -- \
  $'DISPATCH_ID=D1\nSLICE_IDS=S1\n## Goal\nfinish S1\n' \
  >"$TMP/t3.out" 2>"$TMP/t3.err"
st=$?
set -e
if [[ "$st" -eq 2 ]]; then
  PASS "t3-compact-event-rejected"
else
  FAIL "t3-compact-event-rejected" "exit=$st want=2"
fi

# --- T4: crash (nonzero) still fails; not treated as success ---
HOST4="$TMP/host-crash"
mkdir -p "$HOST4/docs/specs/cpx" "$HOST4/src"
echo 'x' >"$HOST4/src/a.ts"
cat >"$HOST4/docs/specs/cpx/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
EOF
fill_spec "$HOST4/docs/specs/cpx"
export MOCK_CODEX_MODE=crash
set +e
bash "$DISPATCH" \
  --cwd "$HOST4" \
  --unit build \
  --spec cpx \
  --slice S1 \
  --dispatch-id D1 \
  --log-dir "$HOST4/.codex-dispatch-logs" \
  --timeout 20 \
  -- \
  $'DISPATCH_ID=D1\nSLICE_IDS=S1\n## Goal\nfinish S1\n' \
  >"$TMP/t4.out" 2>"$TMP/t4.err"
st=$?
set -e
if [[ "$st" -eq 1 ]]; then
  PASS "t4-codex-crash-nonzero"
else
  FAIL "t4-codex-crash-nonzero" "exit=$st want=1"
fi

# --- T5: unbounded multi-slice still rejected before mock runs ---
export MOCK_CODEX_MODE=complete
: >"$MOCK_DIR/invocations.log"
set +e
bash "$DISPATCH" \
  --cwd "$HOST1" \
  --unit build \
  --spec cpx \
  --slice S1 \
  --log-dir "$LOG1" \
  --timeout 20 \
  -- \
  "do remaining slices S1|S2 now" \
  >"$TMP/t5.out" 2>"$TMP/t5.err"
st=$?
set -e
inv_after="$(wc -l <"$MOCK_DIR/invocations.log" | tr -d ' ')"
if [[ "$st" -eq 2 && "$inv_after" == "0" ]]; then
  PASS "t5-unbounded-rejected-before-exec"
else
  FAIL "t5-unbounded-rejected-before-exec" "exit=$st inv_lines=$inv_after"
fi

# --- T6: wish-orchestrate merge → one mock exec for S1+S2+S3 ---
HOSTM="$TMP/host-merge"
mkdir -p "$HOSTM/docs/specs/m1" "$HOSTM/src"
echo 'x' >"$HOSTM/src/foo.ts"
cat >"$HOSTM/docs/specs/m1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/foo.ts | | oracle:unit |
| S2 | b | T-002 | src/foo.ts | S1 | oracle:unit |
| S3 | c | T-003 | src/foo.ts | S1 | oracle:unit |
EOF
fill_spec "$HOSTM/docs/specs/m1"
units_json="$(python3 "$PACK_UNITS" "$HOSTM" m1 --json)"
unit_n="$(printf '%s' "$units_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["units"]))')"
[[ "$unit_n" == "1" ]] || FAIL "t6-pack-merged" "units=$unit_n want=1"
export MOCK_CODEX_MODE=complete
export MOCK_CODEX_SLEEP=0
: >"$MOCK_DIR/invocations.log"
set +e
SKIP_SPEC_CHECK=1 bash "$WISH" --cwd "$HOSTM" --spec m1 --parallel 2 \
  >"$TMP/t6.out" 2>"$TMP/t6.err"
st=$?
set -e
inv_n="$(grep -c '^start_ns=' "$MOCK_DIR/invocations.log" || true)"
rid_files=( "$HOSTM"/.codex-dispatch-logs/wish-run-m1-*.run_id )
if [[ "$st" -ne 0 && "$st" -ne 3 ]]; then
  FAIL "t6-wish-merged-dispatch" "exit=$st stderr=$(head -c 400 "$TMP/t6.err" | tr '\n' ' ')"
elif [[ "$inv_n" != "1" ]]; then
  FAIL "t6-wish-merged-one-exec" "mock invocations=$inv_n want=1"
elif [[ ! -s "${rid_files[0]:-}" ]]; then
  FAIL "t6-wish-merged-run-id-file" "missing wish-run-*.run_id"
else
  rid="$(tr -d '[:space:]' <"${rid_files[0]}")"
  python3 "$DETECT" --require-turn "$HOSTM/.codex-dispatch-logs/${rid}.jsonl" >/dev/null \
    && PASS "t6-wish-merged-one-D+turn.completed" \
    || FAIL "t6-wish-merged-jsonl" "run_id=$rid"
fi

# --- T7: parallel edit-wave overlaps, is worktree-ISOLATED, ignores poison meta ---
# Retargeted: the old version asserted two concurrent codex processes sharing one
# --cwd, which is exactly the unsafe shape that shipped. Parallel arms must now land
# in separate git worktrees pinned to one SHA, so the fixture has to be a real repo.
HOSTP="$TMP/host-par"
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
git -C "$HOSTP" init -q
git -C "$HOSTP" -c user.email=t@t -c user.name=t add -A
git -C "$HOSTP" -c user.email=t@t -c user.name=t commit -qm fixture
mkdir -p "$HOSTP/.codex-dispatch-logs"
cat >"$HOSTP/.codex-dispatch-logs/build_20000101T000000Z_1.meta.txt" <<'EOF'
spec=p1
dispatch_id=D1
slice=S1
slices=S1
exit_status=0
run_id=POISON_OLD_D1
EOF
export MOCK_CODEX_MODE=complete
export MOCK_CODEX_SLEEP=0.8
: >"$MOCK_DIR/invocations.log"
t0="$(date +%s%N)"
set +e
SKIP_SPEC_CHECK=1 WISH_WORKTREE_ROOT="$TMP/wt" bash "$WISH" --cwd "$HOSTP" --spec p1 --parallel 2 \
  >"$TMP/t7.out" 2>"$TMP/t7.err"
st=$?
set -e
t1="$(date +%s%N)"
elapsed_ms=$(( (t1 - t0) / 1000000 ))
inv_n="$(grep -c '^start_ns=' "$MOCK_DIR/invocations.log" || true)"
r1="$HOSTP/.codex-dispatch-logs/wish-run-p1-D1.run_id"
r2="$HOSTP/.codex-dispatch-logs/wish-run-p1-D2.run_id"
state="$HOSTP/.codex-dispatch-logs/wish-state-p1.env"

overlap=0
if [[ "$inv_n" -ge 2 ]]; then
  overlap="$(python3 - "$MOCK_DIR/invocations.log" <<'PY'
import re, sys
starts, ends = [], []
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.search(r"start_ns=(\d+)", line)
    if m:
        starts.append(int(m.group(1)))
    m = re.search(r"end_ns=(\d+)", line)
    if m:
        ends.append(int(m.group(1)))
if len(starts) < 2 or len(ends) < 2:
    print(0)
else:
    s1, s2 = starts[0], starts[1]
    e1, e2 = ends[0], ends[1]
    print(1 if (s1 < e2 and s2 < e1) else 0)
PY
)"
fi

if [[ "$st" -ne 0 && "$st" -ne 3 ]]; then
  FAIL "t7-wish-parallel-dispatch" "exit=$st stderr=$(head -c 400 "$TMP/t7.err" | tr '\n' ' ')"
elif [[ "$inv_n" != "2" ]]; then
  FAIL "t7-wish-parallel-two-exec" "invocations=$inv_n want=2"
elif [[ ! -s "$r1" || ! -s "$r2" ]]; then
  FAIL "t7-wish-parallel-run-id-files" "missing $r1 or $r2"
elif [[ "$(tr -d '[:space:]' <"$r1")" == "POISON_OLD_D1" || "$(tr -d '[:space:]' <"$r2")" == "POISON_OLD_D1" ]]; then
  FAIL "t7-wish-parallel-not-poison" "run-id-file returned leftover meta"
elif [[ "$(tr -d '[:space:]' <"$r1")" == "$(tr -d '[:space:]' <"$r2")" ]]; then
  FAIL "t7-wish-parallel-distinct-ids" "both units shared one RUN_ID"
elif [[ "$overlap" != "1" ]]; then
  FAIL "t7-wish-parallel-overlap" "mock exec intervals did not overlap (elapsed=${elapsed_ms}ms)"
elif [[ "$(grep -oE 'cwd=[^ ]+' "$MOCK_DIR/invocations.log" | sort -u | wc -l)" -lt 2 ]]; then
  FAIL "t7-wish-parallel-isolated-cwd" \
    "parallel arms shared one working tree: $(grep -oE 'cwd=[^ ]+' "$MOCK_DIR/invocations.log" | sort -u | tr '\n' ' ')"
elif grep -oE 'cwd=[^ ]+' "$MOCK_DIR/invocations.log" | grep -qxF "cwd=$HOSTP"; then
  FAIL "t7-wish-parallel-not-main-tree" "an arm was dispatched against the main tree $HOSTP"
elif ! { base_sha="$(git -C "$HOSTP" rev-parse HEAD)"
         bad_sha=0
         while IFS= read -r c; do
           wtp="${c#cwd=}"
           [[ -d "$wtp" ]] || { bad_sha=1; break; }
           [[ "$(git -C "$wtp" rev-parse HEAD 2>/dev/null)" == "$base_sha" ]] || { bad_sha=1; break; }
         done < <(grep -oE 'cwd=[^ ]+' "$MOCK_DIR/invocations.log" | sort -u)
         [[ "$bad_sha" -eq 0 ]]; }; then
  FAIL "t7-wish-parallel-pinned-sha" "a worktree was not pinned to the main tree HEAD"
elif [[ -f "$state" ]] && ! grep -q "AWAITING_FALSIFY=1" "$state"; then
  FAIL "t7-wish-parallel-state" "expected AWAITING_FALSIFY=1"
else
  id1="$(tr -d '[:space:]' <"$r1")"
  id2="$(tr -d '[:space:]' <"$r2")"
  if python3 "$DETECT" --require-turn "$HOSTP/.codex-dispatch-logs/${id1}.jsonl" >/dev/null \
    && python3 "$DETECT" --require-turn "$HOSTP/.codex-dispatch-logs/${id2}.jsonl" >/dev/null; then
    PASS "t7-wish-parallel-overlap+run-id-files (${elapsed_ms}ms)"
  else
    FAIL "t7-wish-parallel-jsonl" "turn.completed missing on a parallel unit"
  fi
fi
export MOCK_CODEX_SLEEP=0

# --- T7b: parallel dispatch into a non-git host must be REFUSED, not shared ---
# Sharing one tree between concurrent execs is unsafe; degrading to it silently is
# worse than failing. The operator gets told to init git or drop to --parallel 1.
HOSTNG="$TMP/host-par-nogit"
mkdir -p "$HOSTNG/docs/specs/p1" "$HOSTNG/modules/track/collection/vrl" "$HOSTNG/infra/postgres/init"
echo 'a' >"$HOSTNG/modules/track/collection/vrl/sa.vrl"
echo 'b' >"$HOSTNG/infra/postgres/init/01.sql"
cat >"$HOSTNG/docs/specs/p1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | coll | T-001 | modules/track/collection/vrl/sa.vrl | | oracle:unit |
| S2 | pg | T-002 | infra/postgres/init/01.sql | | oracle:unit |
EOF
fill_spec "$HOSTNG/docs/specs/p1"
: >"$MOCK_DIR/invocations.log"
set +e
SKIP_SPEC_CHECK=1 WISH_WORKTREE_ROOT="$TMP/wt-ng" bash "$WISH" --cwd "$HOSTNG" --spec p1 --parallel 2 \
  >"$TMP/t7b.out" 2>"$TMP/t7b.err"
stng=$?
set -e
ng_inv="$(grep -c '^start_ns=' "$MOCK_DIR/invocations.log" || true)"
if [[ "$stng" -eq 0 || "$stng" -eq 3 ]]; then
  FAIL "t7b-nogit-parallel-refused" "expected refusal, got exit=$stng"
elif [[ "$ng_inv" != "0" ]]; then
  FAIL "t7b-nogit-no-dispatch" "refused but still invoked codex $ng_inv time(s)"
elif ! grep -qi 'worktree isolation' "$TMP/t7b.err"; then
  FAIL "t7b-nogit-message" "refusal did not explain worktree isolation: $(head -c 200 "$TMP/t7b.err" | tr '\n' ' ')"
else
  PASS "t7b-nogit-parallel-refused (exit=$stng, zero dispatches)"
fi

# --- T8: wish-orchestrate no-turn → hard fail, does not record success ---
HOST8="$TMP/host-wish-noturn"
mkdir -p "$HOST8/docs/specs/n1" "$HOST8/src"
echo 'x' >"$HOST8/src/a.ts"
cat >"$HOST8/docs/specs/n1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | a | T-001 | src/a.ts | | oracle:unit |
EOF
fill_spec "$HOST8/docs/specs/n1"
export MOCK_CODEX_MODE=no-turn
set +e
SKIP_SPEC_CHECK=1 bash "$WISH" --cwd "$HOST8" --spec n1 \
  >"$TMP/t8.out" 2>"$TMP/t8.err"
st=$?
set -e
if [[ "$st" -eq 2 ]]; then
  PASS "t8-wish-no-turn-hard-fail"
else
  FAIL "t8-wish-no-turn-hard-fail" "exit=$st want=2 stderr=$(head -c 300 "$TMP/t8.err" | tr '\n' ' ')"
fi

# --- T10: quota exhaustion is its own failure class, not an implementation failure ---
HOSTQ="$TMP/host-quota"
mkdir -p "$HOSTQ/docs/specs/q1" "$HOSTQ/src"
echo 'x' >"$HOSTQ/src/a.ts"
cat >"$HOSTQ/docs/specs/q1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | web | T-001 | src/a.ts | | oracle:unit |
EOF
fill_spec "$HOSTQ/docs/specs/q1"
export MOCK_CODEX_MODE=quota
set +e
SKIP_SPEC_CHECK=1 bash "$DISPATCH" --cwd "$HOSTQ" --unit build --slice S1 --spec q1 \
  -- "DISPATCH_ID=D1 SLICE_IDS=S1 probe" >"$TMP/t10.out" 2>"$TMP/t10.err"
stq=$?
set -e
export MOCK_CODEX_MODE=complete
qmeta="$(ls -t "$HOSTQ/.codex-dispatch-logs"/*.meta.txt 2>/dev/null | head -1)"
if [[ "$stq" -ne 75 ]]; then
  FAIL "t10-quota-exit-class" "exit=$stq want=75 (EX_TEMPFAIL) — quota conflated with a real failure"
elif [[ -z "$qmeta" ]] || ! grep -q '^failure_class=quota$' "$qmeta"; then
  FAIL "t10-quota-meta" "meta missing failure_class=quota ($qmeta)"
elif ! grep -q '^quota_retry_hint=' "$qmeta"; then
  FAIL "t10-quota-retry-hint" "meta missing quota_retry_hint (operator cannot tell when to retry)"
else
  PASS "t10-quota-class+retry-hint"
fi

# --- T10b: quota detection must NOT fire on a run that merely *mentions* quotas ---
# The first version grepped the whole jsonl; this repo's own scripts contain the phrase,
# so any dispatch that read them would have been misreported as quota-exhausted.
export MOCK_CODEX_MODE=quota-decoy
set +e
SKIP_SPEC_CHECK=1 bash "$DISPATCH" --cwd "$HOSTQ" --unit build --slice S1 --spec q1 \
  --log-dir "$HOSTQ/.codex-dispatch-logs-decoy" \
  -- "DISPATCH_ID=D9 SLICE_IDS=S1 probe" >"$TMP/t10b.out" 2>"$TMP/t10b.err"
stqd=$?
set -e
export MOCK_CODEX_MODE=complete
dmeta="$(ls -t "$HOSTQ/.codex-dispatch-logs-decoy"/*.meta.txt 2>/dev/null | head -1)"
if [[ "$stqd" -eq 75 ]]; then
  FAIL "t10b-quota-no-false-positive" "a successful run that merely mentions 'usage limit' was classified as quota"
elif [[ -n "$dmeta" ]] && grep -q '^failure_class=quota$' "$dmeta"; then
  FAIL "t10b-quota-no-false-positive" "meta wrongly tagged failure_class=quota"
elif [[ "$stqd" -ne 0 ]]; then
  FAIL "t10b-quota-decoy-run" "decoy run should have succeeded, exit=$stqd: $(head -c 200 "$TMP/t10b.err" | tr '\n' ' ')"
else
  PASS "t10b-quota-no-false-positive"
fi

# --- T11: a REALLY killed dispatch is distinguishable from a success ---
# 9 of 75 real dispatches had no exit_status at all and the conductor could not tell
# success from a crash. This SIGKILLs the process group mid-run: an implementation that
# writes run_state only at the end cannot pass.
KLOG="$HOSTQ/.codex-dispatch-logs-kill"
export MOCK_CODEX_MODE=complete MOCK_CODEX_SLEEP=6
setsid bash -c 'SKIP_SPEC_CHECK=1 exec bash "$1" --cwd "$2" --log-dir "$3" \
  --unit build --slice S1 --spec q1 --dispatch-id DK -- "DISPATCH_ID=DK SLICE_IDS=S1 probe"' \
  _ "$DISPATCH" "$HOSTQ" "$KLOG" >/dev/null 2>&1 &
kpid=$!
sleep 2.5
kill -9 -"$kpid" 2>/dev/null || kill -9 "$kpid" 2>/dev/null || true
wait "$kpid" 2>/dev/null || true
export MOCK_CODEX_SLEEP=0
kmeta="$(ls -t "$KLOG"/*.meta.txt 2>/dev/null | head -1)"
if [[ -z "$kmeta" ]]; then
  FAIL "t11-killed-run-detectable" "no meta written before the run — a killed dispatch leaves no trace"
elif ! grep -q '^run_state=started$' "$kmeta"; then
  FAIL "t11-killed-run-detectable" "meta lacks run_state=started (written after the run?): $kmeta"
elif grep -q '^run_state=finished$' "$kmeta"; then
  FAIL "t11-killed-run-detectable" "killed run still claims run_state=finished"
elif grep -q '^exit_status=' "$kmeta"; then
  FAIL "t11-killed-run-detectable" "killed run recorded an exit_status it never had"
else
  PASS "t11-killed-run-detectable (started, no finished, no exit_status)"
fi

# T11b: the same marker on a healthy run must reach finished (positive control).
hmeta="$(ls -t "$HOSTQ/.codex-dispatch-logs"/*.meta.txt 2>/dev/null | head -1)"
if [[ -n "$hmeta" ]] && grep -q '^run_state=finished$' "$hmeta"; then
  PASS "t11b-healthy-run-finishes"
else
  FAIL "t11b-healthy-run-finishes" "healthy run never recorded run_state=finished ($hmeta)"
fi

# --- T9: mock never ran outside isolated TMP hosts ---
if grep -E ' cwd=' "$MOCK_DIR/invocations.log" | grep -vF "cwd=$TMP" >/dev/null; then
  FAIL "t9-isolation-cwd" "mock exec cwd escaped $TMP"
else
  PASS "t9-isolation-tmp-only"
fi

echo "--- selftest-codex-lifecycle: pass=$pass fail=$fail tmp=$TMP ---"
[[ "$fail" -eq 0 ]]
