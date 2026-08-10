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
PACK="$ROOT/skills/dispatch-codex/scripts/pack_dispatch_units.py"
SCHED="$ROOT/skills/dispatch-codex/scripts/schedule_waves.py"
WISH="$ROOT/skills/dispatch-codex/scripts/wish-orchestrate.sh"
DETECT="$ROOT/skills/dispatch-codex/scripts/detect_compact.py"
RECORD="$ROOT/skills/dispatch-codex/scripts/record-conductor-falsify.sh"
REQUIRE="$ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh"

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

echo "----- 2) pack A→D + schedule waves -----"
python3 "$PACK" "$HOST" live-relay --json | tee "$TMP/graph.json"
python3 "$SCHED" - --edit-parallel 2 <"$TMP/graph.json" | tee "$TMP/waves.json"
set +e
python3 - "$TMP/graph.json" "$TMP/waves.json" <<'PY'
import json, sys
g = json.load(open(sys.argv[1]))
w = json.load(open(sys.argv[2]))
units = {u["id"]: u for u in g["units"]}
assert not g.get("incomplete_allowlist"), g
assert not g.get("too_large"), g
assert set(units) == {"D1", "D2", "D3"}, units.keys()
# D1 must be merged S1+S2
d1, d2, d3 = units["D1"], units["D2"], units["D3"]
assert set(d1["slices"]) == {"S1", "S2"}, d1
assert d2["slices"] == ["S3"], d2
assert d3["slices"] == ["S4"], d3
assert set(d3.get("depends_on_units") or []) == {"D1", "D2"}, d3
waves = w["edit_waves"]
assert len(waves) == 2, waves
assert set(waves[0]) == {"D1", "D2"}, waves
assert waves[1] == ["D3"] or set(waves[1]) == {"D3"}, waves
print("pack/schedule assertions ok", {"units": {k: v["slices"] for k,v in units.items()}, "edit_waves": waves})
PY
pack_st=$?
set -e
[[ "$pack_st" -eq 0 ]] && ok "pack D1={S1,S2} ∥ D2={S3} → D3={S4}" || bad "pack/schedule" "DAG not as designed"

[[ "$fail" -eq 0 ]] || { echo "===== abort before Codex ====="; exit 1; }

LOG="$HOST/.codex-dispatch-logs"
mkdir -p "$LOG"
cat >"$LOG/build_20000101T000000Z_1.meta.txt" <<'EOF'
spec=live-relay
dispatch_id=D1
slice=S1
slices=S1,S2
exit_status=0
run_id=POISON_OLD_D1
EOF

export CODEX_DISPATCH_TIMEOUT_SEC="${CODEX_DISPATCH_TIMEOUT_SEC:-900}"
echo "----- 3) WAVE 1 real Codex (parallel 2) timeout=${CODEX_DISPATCH_TIMEOUT_SEC}s -----"
t0="$(date +%s)"
set +e
bash "$WISH" --cwd "$HOST" --spec live-relay --parallel 2 --effort medium \
  >"$TMP/wave1.out" 2>"$TMP/wave1.err"
w1=$?
set -e
t1="$(date +%s)"
echo "wave1 exit=$w1 elapsed=$((t1-t0))s (expect 3=falsify gate, or 0 if last wave)"
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

echo "----- 4) falsify WAVE 1 with real pytest (not Codex) -----"
export PYTHONPATH="$HOST"
set +e
bash "$RECORD" --log-dir "$LOG" --run-id "$id1" --slice S1 --cwd "$HOST" -- \
  python3 -m pytest tests/test_token.py tests/test_rate.py -q \
  >"$TMP/falsify-d1.out" 2>"$TMP/falsify-d1.err"
f1=$?
bash "$RECORD" --log-dir "$LOG" --run-id "$id2" --slice S3 --cwd "$HOST" -- \
  python3 -m pytest tests/test_collect.py -q \
  >"$TMP/falsify-d2.out" 2>"$TMP/falsify-d2.err"
f2=$?
set -e
echo "falsify D1 pytest exit=$f1"; tail -n 30 "$TMP/falsify-d1.err"; echo "---"; cat "$LOG/${id1}_falsify.log" 2>/dev/null | tail -n 20
echo "falsify D2 pytest exit=$f2"; tail -n 30 "$TMP/falsify-d2.err"; echo "---"; cat "$LOG/${id2}_falsify.log" 2>/dev/null | tail -n 20

if [[ "$f1" -ne 0 || "$f2" -ne 0 ]]; then
  bad "wave1-falsify-pytest" "D1=$f1 D2=$f2 — Codex did not make wave-1 tests green"
  echo "===== SCENARIO SUMMARY fail=$fail (stop before wave 2) host=$HOST ====="
  SCENARIO_FAIL=1
  KEEP=1
  exit 1
fi
ok "wave1 pytest falsify D1+D2"

bash "$REQUIRE" --log-dir "$LOG" --run-id "$id1"
bash "$REQUIRE" --log-dir "$LOG" --run-id "$id2"
ok "wave1 require-falsify both run_ids"

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

echo "----- 6) falsify WAVE 2 + full suite -----"
set +e
bash "$RECORD" --log-dir "$LOG" --run-id "$id3" --slice S4 --cwd "$HOST" -- \
  python3 -m pytest tests/test_gateway.py -q \
  >"$TMP/falsify-d3.out" 2>"$TMP/falsify-d3.err"
f3=$?
( cd "$HOST" && PYTHONPATH=. python3 -m pytest tests -q ) >"$TMP/pytest-final.txt" 2>&1
full=$?
set -e
echo "falsify D3 exit=$f3"; tail -n 20 "$TMP/falsify-d3.err"; cat "$LOG/${id3}_falsify.log" 2>/dev/null | tail -n 15
echo "full pytest exit=$full"; tail -n 40 "$TMP/pytest-final.txt"

[[ "$f3" -eq 0 ]] && ok "wave2 pytest falsify D3" || bad "wave2-falsify" "gateway tests still red"
[[ "$full" -eq 0 ]] && ok "full pytest green after both waves" || bad "full-pytest" "suite not green"

if [[ "$f3" -eq 0 ]]; then
  bash "$REQUIRE" --log-dir "$LOG" --run-id "$id3"
  ok "wave2 require-falsify D3"
fi

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
