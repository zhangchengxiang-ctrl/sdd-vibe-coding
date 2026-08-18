#!/usr/bin/env bash
# LIVE complex scenario: real Codex + real check_spec + multi-D DAG.
# Isolated /tmp copy of fixtures/live-relay. Never -C a product repo.
#
# Wave 1: D1(S1+S2 auth merge) ∥ D2(S3 ingest)
# Falsify pytest on each run_id
# Wave 2: D3(S4 gateway depends on S1+S3)
# Final pytest all
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FIX="$ROOT/skills/dispatch-codex/fixtures/live-relay"
CHECK="$ROOT/skills/spec/scripts/check_spec.py"
PACK_PY="$ROOT/skills/dispatch-codex/scripts/build_context_pack.py"
WISH="$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh"
DETECT="$ROOT/skills/dispatch-codex/scripts/detect_compact.py"
SHIP="$ROOT/skills/dispatch-codex/scripts/ship.sh"

command -v codex >/dev/null || { echo "SCENARIO FAIL: codex not on PATH" >&2; exit 2; }
[[ -d "$FIX" ]] || { echo "SCENARIO FAIL: missing fixture $FIX" >&2; exit 2; }

TMP="$(mktemp -d /tmp/sdd-scenario-live.XXXXXX)"
# Keep host on failure for inspection; delete only on full success unless KEEP=1
HOST="$TMP/host"
KEEP="${SCENARIO_KEEP:-0}"
cleanup() {
  if [[ "$KEEP" == "1" || "${SCENARIO_FAIL:-0}" == "1" ]]; then
    echo "SCENARIO keep host=$HOST tmp=$TMP" >&2
  else
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

echo "======== SCENARIO live-relay ========"
echo "fixture=$FIX"
echo "host=$HOST (copy; product repos untouched)"

mkdir -p "$HOST"
cp -a "$FIX"/. "$HOST"/
git -C "$HOST" init -q
git -C "$HOST" -c user.email=sdd-scenario@example.test -c user.name=sdd-scenario add -A
git -C "$HOST" -c user.email=sdd-scenario@example.test -c user.name=sdd-scenario commit -qm 'live-relay red stubs'

fail=0
ok() { echo "SCENARIO PASS  $1"; }
bad() { echo "SCENARIO FAIL  $1 — $2" >&2; fail=$((fail + 1)); SCENARIO_FAIL=1; }

echo "----- 0) stub tests must be RED before Codex -----"
set +e
( cd "$HOST" && PYTHONPATH=. python3 -m pytest tests -q ) >"$TMP/pytest-red.txt" 2>&1
red_st=$?
set -e
echo "(pytest stub exit=$red_st; expect non-zero)"
tail -n 20 "$TMP/pytest-red.txt" || true
if [[ "$red_st" -eq 0 ]]; then
  bad "pre-red" "stubs already pass; scenario has nothing for Codex to do"
else
  ok "pre-red pytest (exit=$red_st)"
fi

echo "----- 1) check_spec (NO SKIP_SPEC_CHECK) -----"
set +e
python3 "$CHECK" "$HOST" live-relay --skip-agents >"$TMP/check_spec.out" 2>"$TMP/check_spec.err"
cs=$?
set -e
cat "$TMP/check_spec.out" || true
cat "$TMP/check_spec.err" >&2 || true
if [[ "$cs" -ne 0 ]]; then
  bad "check_spec" "exit=$cs — refusing to dispatch Codex on invalid Spec"
  echo "===== SCENARIO SUMMARY fail=$fail (aborted before Codex) ====="
  exit 1
fi
ok "check_spec live-relay"

echo "----- 2) schedule slice waves (A == D) -----"
python3 "$PACK_PY" --waves "$HOST" live-relay --parallel 2 | tee "$TMP/waves.json"
set +e
python3 - "$TMP/waves.json" <<'ASSERT_PY'
import json, sys
w = json.load(open(sys.argv[1]))
assert not w.get("incomplete_allowlist"), w
# A slice is the dispatch unit: no packer merges S1+S2 into a D1 any more. S1 and S2 are
# independent, S3 is independent, S4 depends on both — so wave 1 is capped at --parallel 2 and
# S4 cannot start until its deps land.
assert w["slices"] == ["S1", "S2", "S3", "S4"], w
waves = w["waves"]
assert all(len(x) <= 2 for x in waves), waves
assert "S4" not in sum(waves[:-1], []), waves
flat = sum(waves, [])
assert sorted(flat) == ["S1", "S2", "S3", "S4"] and len(flat) == 4, waves
print("wave assertions ok", waves)
ASSERT_PY
echo "----- 3) WAVE 1 real Codex (parallel 2) timeout=${CODEX_DISPATCH_TIMEOUT_SEC}s -----"
t0="$(date +%s)"
set +e
bash "$WISH" --cwd "$HOST" --spec live-relay --parallel 2 --effort medium \
  >"$TMP/wave1.out" 2>"$TMP/wave1.err"
w1=$?
set -e
t1="$(date +%s)"
echo "wave1 exit=$w1 elapsed=$((t1-t0))s (expect 3=replay gate, or 0 if last wave)"
tail -n 50 "$TMP/wave1.err" || true

if [[ "$w1" -ne 0 && "$w1" -ne 3 ]]; then
  bad "wave1-dispatch" "wish-orchestrate exit=$w1"
  echo "===== SCENARIO SUMMARY fail=$fail ====="
  exit 1
fi
ok "wave1 wish-orchestrate exit=$w1"

rid1_f="$LOG/wish-run-live-relay-D1.run_id"
rid2_f="$LOG/wish-run-live-relay-D2.run_id"
[[ -s "$rid1_f" && -s "$rid2_f" ]] || bad "wave1-run-id-files" "missing $rid1_f or $rid2_f"
id1="$(tr -d '[:space:]' <"$rid1_f" 2>/dev/null || true)"
id2="$(tr -d '[:space:]' <"$rid2_f" 2>/dev/null || true)"
echo "RUN_ID D1=$id1"
echo "RUN_ID D2=$id2"
[[ "$id1" != "POISON_OLD_D1" && "$id2" != "POISON_OLD_D1" ]] && ok "wave1 not poisoned by leftover meta" \
  || bad "wave1-poison" "used POISON_OLD_D1"
[[ -n "$id1" && -n "$id2" && "$id1" != "$id2" ]] && ok "wave1 distinct RUN_IDs" \
  || bad "wave1-distinct" "id1=$id1 id2=$id2"

for rid in "$id1" "$id2"; do
  [[ -n "$rid" ]] || continue
  jsonl="$LOG/${rid}.jsonl"
  last="$LOG/${rid}.last.md"
  if [[ ! -s "$jsonl" ]]; then
    bad "wave1-jsonl-$rid" "missing jsonl"
    continue
  fi
  echo "----- jsonl $rid types -----"
  python3 - "$jsonl" <<'PY'
import json,sys,collections
c=collections.Counter(); last=None
for line in open(sys.argv[1],encoding="utf-8",errors="replace"):
    line=line.strip()
    if not line: continue
    try: o=json.loads(line)
    except Exception: continue
    last=o
    t=o.get("type") or "?"
    item=o.get("item") if isinstance(o.get("item"),dict) else {}
    c[f"{t}:{item.get('type')}" if item.get("type") else str(t)] += 1
print(dict(c)); print("last_type", (last or {}).get("type"))
if last and last.get("type")=="turn.completed":
    print("usage", last.get("usage"))
PY
  if python3 "$DETECT" --require-turn "$jsonl"; then
    ok "wave1 $rid turn.completed"
  else
    bad "wave1-$rid-turn" "detect_compact --require-turn failed"
  fi
  [[ -s "$last" ]] && ok "wave1 $rid last.md ($(wc -c <"$last")B)" \
    || bad "wave1-$rid-last" "missing --output-last-message"
done

echo "----- 4) replay WAVE 1 Oracles (ship.sh, not Codex) -----"
# Was: record-conductor-falsify running pytest and writing a COMMAND/EXIT_CODE/VERDICT log,
# then require-conductor-falsify reading it back. ship.sh replays the Oracle the dispatch
# froze, and proves it was RED on that dispatch's own baseline first — which the attestation
# never did, because a conductor-typed PASS only ever proved the conductor typed it.
export PYTHONPATH="$HOST"
set +e
bash "$SHIP" --host "$HOST" --spec live-relay --from-meta "$LOG/${id1}.meta.txt" \
  >"$TMP/replay-d1.out" 2>"$TMP/replay-d1.err"
f1=$?
bash "$SHIP" --host "$HOST" --spec live-relay --from-meta "$LOG/${id2}.meta.txt" \
  >"$TMP/replay-d2.out" 2>"$TMP/replay-d2.err"
f2=$?
set -e
echo "replay D1 exit=$f1"; tail -n 30 "$TMP/replay-d1.err"
echo "replay D2 exit=$f2"; tail -n 30 "$TMP/replay-d2.err"

if [[ "$f1" -ne 0 || "$f2" -ne 0 ]]; then
  bad "wave1-replay" "D1=$f1 D2=$f2 — wave-1 Oracles are not red-then-green"
  echo "===== SCENARIO SUMMARY fail=$fail (stop before wave 2) host=$HOST ====="
  SCENARIO_FAIL=1
  KEEP=1
  exit 1
fi
ok "wave1 red-green replay D1+D2"

echo "----- 5) WAVE 2 real Codex (D3 gateway) -----"
t2="$(date +%s)"
set +e
bash "$WISH" --cwd "$HOST" --spec live-relay --parallel 2 --effort medium \
  >"$TMP/wave2.out" 2>"$TMP/wave2.err"
w2=$?
set -e
t3="$(date +%s)"
echo "wave2 exit=$w2 elapsed=$((t3-t2))s"
tail -n 40 "$TMP/wave2.err" || true
if [[ "$w2" -ne 0 && "$w2" -ne 3 ]]; then
  bad "wave2-dispatch" "exit=$w2"
  SCENARIO_FAIL=1; KEEP=1; exit 1
fi
ok "wave2 wish-orchestrate exit=$w2"

rid3_f="$LOG/wish-run-live-relay-D3.run_id"
[[ -s "$rid3_f" ]] || bad "wave2-run-id" "missing $rid3_f"
id3="$(tr -d '[:space:]' <"$rid3_f" 2>/dev/null || true)"
echo "RUN_ID D3=$id3"
if [[ -n "$id3" && -s "$LOG/${id3}.jsonl" ]] && python3 "$DETECT" --require-turn "$LOG/${id3}.jsonl"; then
  ok "wave2 D3 turn.completed"
else
  bad "wave2-turn" "no turn.completed for D3"
fi
[[ -s "$LOG/${id3}.last.md" ]] && ok "wave2 D3 last.md" || bad "wave2-last" "missing last.md"

echo "----- 6) replay WAVE 2 + full suite -----"
set +e
bash "$SHIP" --host "$HOST" --spec live-relay --from-meta "$LOG/${id3}.meta.txt" \
  >"$TMP/replay-d3.out" 2>"$TMP/replay-d3.err"
f3=$?
( cd "$HOST" && PYTHONPATH=. python3 -m pytest tests -q ) >"$TMP/pytest-final.txt" 2>&1
full=$?
set -e
echo "replay D3 exit=$f3"; tail -n 20 "$TMP/replay-d3.err"
echo "full pytest exit=$full"; tail -n 40 "$TMP/pytest-final.txt"

[[ "$f3" -eq 0 ]] && ok "wave2 red-green replay D3" || bad "wave2-replay" "gateway Oracle not red-then-green"
[[ "$full" -eq 0 ]] && ok "full pytest green after both waves" || bad "full-pytest" "suite not green"

echo "----- 7) isolation: host under TMP, not product repos -----"
case "$HOST" in
  /tmp/sdd-scenario-live.*) ok "host isolated under $TMP" ;;
  *) bad "isolation" "host=$HOST" ;;
esac

echo "===== SCENARIO SUMMARY fail=$fail host=$HOST ====="
echo "D1=$id1 D2=$id2 D3=$id3 wave1_s=$((t1-t0)) wave2_s=$((t3-t2))"
if [[ "$fail" -ne 0 ]]; then
  SCENARIO_FAIL=1
  KEEP=1
  exit 1
fi
# success: keep logs briefly? default delete; set KEEP=1 to inspect
exit 0
