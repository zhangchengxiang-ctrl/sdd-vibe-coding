#!/usr/bin/env bash
# LIVE Codex lifecycle test — real `codex exec`, isolated /tmp host only.
# Never points -C at sibling product repos.
#
#   bash skills/dispatch-codex/scripts/selftest-codex-lifecycle-live.sh
#
# Requires: `codex` on PATH + existing auth. Burns one short Build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DISPATCH="$ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"
DETECT="$ROOT/skills/dispatch-codex/scripts/detect_compact.py"

command -v codex >/dev/null || { echo "LIVE FAIL: codex CLI not on PATH" >&2; exit 2; }
command -v timeout >/dev/null || { echo "LIVE FAIL: GNU timeout missing" >&2; exit 2; }

TMP="$(mktemp -d /tmp/sdd-real-codex.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "LIVE host=$TMP (isolated; not a product repo)"

HOST="$TMP/host"
mkdir -p "$HOST/src" "$HOST/docs/specs/live1"
printf '%s\n' 'export const n = 0' >"$HOST/src/marker.ts"
cat >"$HOST/docs/specs/live1/plan.md" <<'EOF'
| 切片 ID | 入口 | 完成定义（链 T-xxx） | 触及路径 | 依赖 | 备注 |
| S1 | marker | T-001 | src/marker.ts | | oracle:unit |
EOF
for f in VERSION.md run.md; do
  printf '# %s\n\nLive lifecycle fixture (%s). Isolated tmp host.\n' "$f" "$f" \
    >"$HOST/docs/specs/live1/$f"
done
# A real Requirements table and a real machine Oracle: with a placeholder tests.md the dispatch
# throat has nothing to freeze, so the freeze and the replay would be silently skipped and this
# live run would prove less than it looks like it proves.
cat >"$HOST/docs/specs/live1/contract.md" <<'EOF'
# Contract

## Requirements

| ID | 需求 | 优先级 | 证据级 | AC 摘要（行为） | Tests |
|---|---|---|---|---|---|
| R-001 | marker exports n = 1 | P0 | Verified | src/marker.ts changes | T-001 |
EOF
cat >"$HOST/docs/specs/live1/tests.md" <<'EOF'
# Tests

## 索引

| ID | R |
|---|---|
| T-001 | R-001 |

## T-001 · marker is bumped

### Given

- src/marker.ts exports n = 0

### When

1. run the oracle

### Then（Oracle）

- src/marker.ts contains `export const n = 1`, and does not contain `n = 0`

### 自动化

- 命令：`bash -c "grep -q 'export const n = 1' src/marker.ts"`
- 预期 Evidence Kind：`unit`
EOF
git -C "$HOST" init -q
git -C "$HOST" -c user.email=sdd-live@example.test -c user.name=sdd-live add -A
git -C "$HOST" -c user.email=sdd-live@example.test -c user.name=sdd-live commit -qm init

RID="$TMP/run.id"
LOG="$HOST/.codex-dispatch-logs"
mkdir -p "$LOG"

PROMPT=$(cat <<'EOF'
DISPATCH_ID=D1
SLICE_IDS=S1
## Goal
Change only src/marker.ts so it exports `n = 1` (keep `export const n`). Stop.
## Context
- docs/specs/live1/{contract,tests,plan,run}.md
- paths: src/marker.ts
## Constraints
Do not explore the machine. Do not modify any other path. Do not commit. Do not compact onward.
## Done when
src/marker.ts contains `export const n = 1`.
EOF
)

echo "LIVE: invoking real codex via codex-dispatch.sh (timeout 180s, workspace-write)"
set +e
SKIP_SPEC_CHECK=1 bash "$DISPATCH" \
  --cwd "$HOST" \
  --unit build \
  --effort medium \
  --sandbox workspace-write \
  --timeout 180 \
  --spec live1 \
  --slice S1 \
  --dispatch-id D1 \
  --run-id-file "$RID" \
  --log-dir "$LOG" \
  -- \
  "$PROMPT" \
  >"$TMP/dispatch.out" 2>"$TMP/dispatch.err"
st=$?
set -e

echo "LIVE dispatch exit=$st"
echo "----- dispatch stderr (tail) -----"
tail -n 40 "$TMP/dispatch.err" || true

fail=0
ok() { echo "LIVE PASS  $1"; }
bad() { echo "LIVE FAIL  $1 — $2" >&2; fail=$((fail + 1)); }

[[ -s "$RID" ]] || bad "run-id-file" "missing $RID"
rid="$(tr -d '[:space:]' <"$RID" 2>/dev/null || true)"
[[ -n "$rid" ]] || bad "run-id-nonempty" "empty run-id-file"
meta="$LOG/${rid}.meta.txt"
jsonl="$LOG/${rid}.jsonl"
last="$LOG/${rid}.last.md"

[[ -f "$meta" ]] || bad "meta" "missing $meta"
[[ -f "$jsonl" ]] || bad "jsonl" "missing $jsonl (Codex --json never teed?)"
[[ -s "$jsonl" ]] || bad "jsonl-nonempty" "jsonl empty"

if [[ -f "$meta" ]]; then
  echo "----- meta -----"
  cat "$meta"
  meta_rid="$(grep '^run_id=' "$meta" | head -1 | cut -d= -f2- || true)"
  [[ "$rid" == "$meta_rid" ]] && ok "run-id-file==meta.run_id ($rid)" \
    || bad "run-id-match" "file=$rid meta=$meta_rid"
  grep -q '^dispatch_id=D1$' "$meta" && ok "meta.dispatch_id=D1" \
    || bad "meta-dispatch-id" "not D1"
  # The Oracle must have been frozen at dispatch: ship.sh replays that file, not whatever
  # tests.md says by the time anyone looks.
  frz="$(sed -n 's/^oracles_file=//p' "$meta" | head -1)"
  if [[ -n "$frz" && -s "$frz" ]] && grep -q $'^T-001\tmachine\t' "$frz"; then
    ok "oracle frozen at dispatch ($(basename "$frz"))"
  else
    bad "oracle-freeze-live" "meta has no usable oracles_file (got '${frz:-none}')"
  fi
  # Budget by a count, on a real log.
  acts="$(sed -n 's/^actions=//p' "$meta" | head -1)"
  if [[ "$acts" =~ ^[1-9][0-9]*$ ]]; then
    ok "actions counted on a real run (actions=$acts)"
  else
    bad "actions-live" "meta has no non-zero actions= (got '${acts:-none}')"
  fi
fi

if [[ -s "$jsonl" ]]; then
  # The whole chain, on a real dispatch: the Oracle frozen above must be RED on the commit this
# dispatch recorded as its baseline, and GREEN on the tree Codex just changed. A mock cannot
# prove this — the baseline worktree and the real edit are both required.
SHIP="$ROOT/skills/dispatch-codex/scripts/ship.sh"
if [[ -f "$meta" && -f "$SHIP" ]]; then
  set +e
  bash "$SHIP" --host "$HOST" --spec live1 --slice S1 --from-meta "$meta" \
    >"$TMP/ship.log" 2>&1
  ship_st=$?
  set -e
  echo "----- ship.sh (tail) -----"
  tail -n 12 "$TMP/ship.log" || true
  if [[ "$ship_st" -eq 0 ]] && grep -q 'baseline RED' "$TMP/ship.log" \
     && grep -q 'verify GREEN' "$TMP/ship.log"; then
    ok "red-green replay on a real dispatch (baseline RED -> verify GREEN)"
  else
    bad "replay-live" "exit=$ship_st; the frozen Oracle did not go red-then-green (see above)"
  fi
fi

echo "----- jsonl event types -----"
  python3 - "$jsonl" <<'PY'
import json, sys, collections
c = collections.Counter()
last = None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        o = json.loads(line)
    except json.JSONDecodeError:
        continue
    last = o
    t = o.get("type") or "?"
    item = o.get("item") if isinstance(o.get("item"), dict) else {}
    if item.get("type"):
        c[f"{t}:{item.get('type')}"] += 1
    else:
        c[str(t)] += 1
print("counts:", dict(c))
print("last_type:", (last or {}).get("type"))
print("last:", json.dumps(last, ensure_ascii=False)[:800] if last else None)
PY
  if python3 "$DETECT" --require-turn "$jsonl"; then
    ok "detect_compact --require-turn on REAL jsonl"
  else
    bad "detect_compact-real" "real jsonl failed --require-turn (see stdout above)"
  fi
  # Prove old token-walk heuristic would lie on this real log
  old_would_fail="$(python3 - "$jsonl" <<'PY'
import json, sys
max_t = 0
keys = {"input_tokens","prompt_tokens","total_tokens","input_token_count","token_count","context_tokens"}
def walk(o):
    global max_t
    if isinstance(o, dict):
        for k,v in o.items():
            if str(k).lower() in keys and isinstance(v,(int,float)) and v>0:
                max_t = max(max_t, int(v))
            else:
                walk(v)
    elif isinstance(o, list):
        for x in o:
            walk(x)
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    line=line.strip()
    if not line: continue
    try: walk(json.loads(line))
    except Exception: pass
print(max_t)
PY
)"
  echo "LIVE note: max usage.input_tokens on this log = $old_would_fail (old >=250k tripwire would $([[ "${old_would_fail:-0}" -ge 250000 ]] && echo FAIL || echo pass))"
fi

if [[ -s "$last" ]]; then
  ok "output-last-message written ($(wc -c <"$last") bytes)"
  echo "----- last.md (head) -----"
  head -c 600 "$last"; echo
else
  bad "last-message" "Codex --output-last-message file missing/empty: $last"
fi

if grep -q 'export const n = 1' "$HOST/src/marker.ts"; then
  ok "repo artifact: src/marker.ts n=1"
else
  echo "LIVE note: marker.ts after run:"; cat "$HOST/src/marker.ts" || true
  # Artifact miss is a Codex task miss, not a lifecycle-signal miss — still report
  bad "artifact" "src/marker.ts was not updated to n=1 (Codex did not finish the tiny task)"
fi

[[ "$st" -eq 0 ]] && ok "codex-dispatch exit 0" || bad "dispatch-exit" "exit=$st (timeout=124)"

echo "===== LIVE SUMMARY fail=$fail host=$HOST run_id=${rid:-?} ====="
[[ "$fail" -eq 0 ]]
