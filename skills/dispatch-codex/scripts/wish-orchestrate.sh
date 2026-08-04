#!/usr/bin/env bash
# Wish / autopilot orchestration: Context Pack per slice → Codex Build (one slice each).
#
# Usage:
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID [--slice S1] [--effort medium|high]
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --list
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --pack-only --slice S1
#
# Does NOT run Verify / human acceptance (钉 3).
#
# Falsify gate (default on):
#   After each successful Build, records run_id and exits 3 if more slices remain
#   (or always leaves awaiting_falsify). Next invocation refuses to dispatch until
#   require-conductor-falsify sees VERDICT: PASS for that run_id.
#   SKIP_FALSIFY_GATE=1 — maintainer-only bypass.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wish-orchestrate.sh --cwd DIR --spec ID [options]

Required:
  --cwd DIR       Host repo root
  --spec ID       Spec id under SDD docs/specs/

Options:
  --slice ID      Only this slice (default: all slices in plan.md order)
  --effort LVL    medium|high (default: medium)
  --list          Print slice ids and exit
  --pack-only     Only emit Context Pack prompt for --slice (no Codex)
  --dry-run       Print dispatch commands; do not run Codex
  -h, --help

Flow per slice:
  1) Clear prior awaiting_falsify (VERDICT: PASS required) unless first
  2) build_context_pack.py → prompt file
  3) codex-dispatch.sh --unit build --spec --slice
  4) Record run_id; if more slices in this invocation → exit 3 (falsify then re-run)

Exit codes:
  0  last requested slice dispatched (still falsify before claiming done)
  3  slice dispatched; falsify PASS required before next slice / continue
  2  usage / hard failure
EOF
}

die() { echo "wish-orchestrate: $*" >&2; exit 2; }

CWD=""
SPEC_ID=""
SLICE_ID=""
EFFORT="${CODEX_DISPATCH_EFFORT:-medium}"
LIST=0
PACK_ONLY=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --spec) SPEC_ID="${2:-}"; shift 2 ;;
    --slice) SLICE_ID="${2:-}"; shift 2 ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --pack-only) PACK_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -n "$CWD" ]] || die "--cwd required"
[[ -d "$CWD" ]] || die "cwd not a directory: $CWD"
CWD="$(cd "$CWD" && pwd)"
[[ -n "$SPEC_ID" ]] || die "--spec required"

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PACK_PY="$PLUGIN_ROOT/skills/dispatch-codex/scripts/build_context_pack.py"
DISPATCH="$PLUGIN_ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"
REQUIRE_FALSIFY="$PLUGIN_ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh"
[[ -f "$PACK_PY" ]] || die "missing $PACK_PY"
[[ -f "$DISPATCH" ]] || die "missing $DISPATCH"
[[ -f "$REQUIRE_FALSIFY" ]] || die "missing $REQUIRE_FALSIFY"

if [[ "$LIST" == "1" ]]; then
  python3 "$PACK_PY" "$CWD" "$SPEC_ID" --list
  exit 0
fi

mapfile -t SLICES < <(python3 "$PACK_PY" "$CWD" "$SPEC_ID" --list)
[[ ${#SLICES[@]} -gt 0 ]] || die "no slices in plan.md for $SPEC_ID"

if [[ -n "$SLICE_ID" ]]; then
  SLICES=("$SLICE_ID")
fi

LOG_DIR="${CODEX_DISPATCH_LOG_DIR:-$CWD/.codex-dispatch-logs}"
mkdir -p "$LOG_DIR"
PACK_DIR="$LOG_DIR/context-packs"
mkdir -p "$PACK_DIR"
STATE_FILE="$LOG_DIR/wish-state-${SPEC_ID}.env"

load_state() {
  AWAITING_FALSIFY=0
  LAST_RUN_ID=""
  LAST_SLICE=""
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

save_state() {
  cat >"$STATE_FILE" <<EOF
AWAITING_FALSIFY=$AWAITING_FALSIFY
LAST_RUN_ID=$LAST_RUN_ID
LAST_SLICE=$LAST_SLICE
SPEC_ID=$SPEC_ID
EOF
}

clear_awaiting() {
  AWAITING_FALSIFY=0
  save_state
}

resolve_latest_run_id() {
  local sid="$1"
  local f run_id=""
  shopt -s nullglob
  for f in $(ls -t "$LOG_DIR"/build_*.meta.txt 2>/dev/null); do
    if grep -q "^spec=${SPEC_ID}$" "$f" 2>/dev/null \
      && grep -q "^slice=${sid}$" "$f" 2>/dev/null \
      && grep -q "^exit_status=0$" "$f" 2>/dev/null; then
      run_id="$(grep '^run_id=' "$f" | head -1 | cut -d= -f2-)"
      break
    fi
  done
  shopt -u nullglob
  printf '%s' "$run_id"
}

enforce_prior_falsify() {
  if [[ "${SKIP_FALSIFY_GATE:-0}" == "1" ]]; then
    echo "wish-orchestrate: WARN SKIP_FALSIFY_GATE=1 — maintainer-only; never in user sessions" >&2
    clear_awaiting
    return 0
  fi
  load_state
  if [[ "${AWAITING_FALSIFY:-0}" != "1" || -z "${LAST_RUN_ID:-}" ]]; then
    return 0
  fi
  echo "wish-orchestrate: prior slice ${LAST_SLICE:-?} awaits falsify ($LAST_RUN_ID)" >&2
  if ! bash "$REQUIRE_FALSIFY" --log-dir "$LOG_DIR" --run-id "$LAST_RUN_ID"; then
    die "falsify gate blocked: write $LOG_DIR/${LAST_RUN_ID}_falsify.log with VERDICT: PASS, then re-run"
  fi
  clear_awaiting
}

echo "wish-orchestrate: host=$CWD spec=$SPEC_ID slices=${SLICES[*]} effort=$EFFORT" >&2

enforce_prior_falsify

idx=0
n=${#SLICES[@]}
for sid in "${SLICES[@]}"; do
  echo "wish-orchestrate: === pack + build slice=$sid ===" >&2
  PACK_FILE="$PACK_DIR/${SPEC_ID}_${sid}_$(date -u +%Y%m%dT%H%M%SZ).txt"
  if ! python3 "$PACK_PY" "$CWD" "$SPEC_ID" "$sid" >"$PACK_FILE"; then
    die "context pack failed for slice $sid"
  fi
  echo "wish-orchestrate: pack=$PACK_FILE" >&2

  if [[ "$PACK_ONLY" == "1" ]]; then
    cat "$PACK_FILE"
    exit 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY-RUN: would dispatch build slice=$sid with pack $PACK_FILE" >&2
    idx=$((idx + 1))
    continue
  fi

  bash "$DISPATCH" \
    --cwd "$CWD" \
    --unit build \
    --effort "$EFFORT" \
    --spec "$SPEC_ID" \
    --slice "$sid" \
    -- "$(cat "$PACK_FILE")"

  RUN_ID="$(resolve_latest_run_id "$sid")"
  [[ -n "$RUN_ID" ]] || die "could not resolve run_id for slice $sid after dispatch"
  AWAITING_FALSIFY=1
  LAST_RUN_ID="$RUN_ID"
  LAST_SLICE="$sid"
  save_state

  echo "wish-orchestrate: slice=$sid dispatched run_id=$RUN_ID" >&2
  echo "wish-orchestrate: NEXT — falsify then: make require-falsify LOG_DIR=$LOG_DIR RUN_ID=$RUN_ID" >&2
  echo "wish-orchestrate: falsify log must contain: VERDICT: $sid PASS" >&2

  idx=$((idx + 1))
  if [[ "$idx" -lt "$n" ]]; then
    echo "wish-orchestrate: stopping before next slice (falsify gate). Re-run after VERDICT: PASS." >&2
    echo "wish-orchestrate: tip: wish-orchestrate --cwd … --spec $SPEC_ID --slice ${SLICES[$idx]}" >&2
    exit 3
  fi
done

echo "wish-orchestrate: requested slices dispatched. Falsify last run_id=${LAST_RUN_ID:-?} then Agent Verify + human-acceptance-pack (not Codex)." >&2
exit 0
