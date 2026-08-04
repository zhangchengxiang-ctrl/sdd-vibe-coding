#!/usr/bin/env bash
# Wish / autopilot orchestration: Context Pack per slice → Codex Build (one slice each).
#
# Usage:
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID [--slice S1] [--effort medium|high]
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --list
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --status
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --pack-only --slice S1
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --force-slice S1   # re-dispatch passed slice
#
# Does NOT run Verify / human acceptance (钉 3). Machine loop = pack→build→structured falsify.
#
# Gates (default on):
#   - flock on wish-lock-<spec> (concurrency)
#   - skip slices already in PASSED_SLICES (idempotency)
#   - after Build: awaiting_falsify; next invoke needs structured VERDICT: PASS
#   - multi-slice one call → exit 3 after first dispatch
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
  --force-slice   Re-dispatch even if slice already in PASSED_SLICES
  --effort LVL    medium|high (default: medium)
  --list          Print slice ids and exit
  --status        Print wish state (passed / awaiting) and exit
  --pack-only     Only emit Context Pack prompt for --slice (no Codex)
  --dry-run       Print dispatch commands; do not run Codex
  -h, --help

Flow per slice:
  1) Acquire flock; clear prior awaiting_falsify (structured PASS) unless first
  2) Skip if slice already PASSED (unless --force-slice)
  3) build_context_pack.py → prompt file
  4) codex-dispatch.sh --unit build --spec --slice
  5) Record run_id; exit 3 if more slices remain (falsify then re-run)

Exit codes:
  0  last requested slice dispatched or all already passed (still falsify last if awaiting)
  3  slice dispatched; structured falsify PASS required before next slice / continue
  2  usage / hard failure
EOF
}

die() { echo "wish-orchestrate: $*" >&2; exit 2; }

CWD=""
SPEC_ID=""
SLICE_ID=""
EFFORT="${CODEX_DISPATCH_EFFORT:-medium}"
LIST=0
STATUS=0
PACK_ONLY=0
DRY_RUN=0
FORCE_SLICE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --spec) SPEC_ID="${2:-}"; shift 2 ;;
    --slice) SLICE_ID="${2:-}"; shift 2 ;;
    --force-slice) FORCE_SLICE=1; shift ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --status) STATUS=1; shift ;;
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
LOCK_FILE="$LOG_DIR/wish-lock-${SPEC_ID}.lock"

# Concurrency: one orchestrator per spec
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  die "lock held: another wish-orchestrate for spec=$SPEC_ID (lock=$LOCK_FILE)"
fi

load_state() {
  AWAITING_FALSIFY=0
  LAST_RUN_ID=""
  LAST_SLICE=""
  PASSED_SLICES=""
  CORRELATION_ID=""
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
PASSED_SLICES='$PASSED_SLICES'
CORRELATION_ID=$CORRELATION_ID
SPEC_ID=$SPEC_ID
EOF
}

clear_awaiting() {
  AWAITING_FALSIFY=0
  save_state
}

mark_slice_passed() {
  local sid="$1"
  case " $PASSED_SLICES " in
    *" $sid "*) ;;
    *) PASSED_SLICES="${PASSED_SLICES:+$PASSED_SLICES }$sid" ;;
  esac
  save_state
}

slice_already_passed() {
  local sid="$1"
  case " $PASSED_SLICES " in
    *" $sid "*) return 0 ;;
    *) return 1 ;;
  esac
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
    if [[ -n "${LAST_SLICE:-}" ]]; then
      mark_slice_passed "$LAST_SLICE"
    fi
    clear_awaiting
    return 0
  fi
  load_state
  if [[ "${AWAITING_FALSIFY:-0}" != "1" || -z "${LAST_RUN_ID:-}" ]]; then
    return 0
  fi
  echo "wish-orchestrate: prior slice ${LAST_SLICE:-?} awaits structured falsify ($LAST_RUN_ID)" >&2
  if ! bash "$REQUIRE_FALSIFY" --log-dir "$LOG_DIR" --run-id "$LAST_RUN_ID"; then
    die "falsify gate blocked: make record-falsify LOG_DIR=$LOG_DIR RUN_ID=$LAST_RUN_ID SLICE=${LAST_SLICE:-S?} -- <cmd>"
  fi
  if [[ -n "${LAST_SLICE:-}" ]]; then
    mark_slice_passed "$LAST_SLICE"
  fi
  clear_awaiting
}

load_state
if [[ -z "${CORRELATION_ID:-}" ]]; then
  CORRELATION_ID="${SPEC_ID}-$(date -u +%Y%m%dT%H%M%SZ)"
  save_state
fi

if [[ "$STATUS" == "1" ]]; then
  echo "wish-orchestrate status:"
  echo "  host=$CWD"
  echo "  spec=$SPEC_ID"
  echo "  correlation_id=${CORRELATION_ID:-}"
  echo "  awaiting_falsify=${AWAITING_FALSIFY:-0}"
  echo "  last_run_id=${LAST_RUN_ID:-}"
  echo "  last_slice=${LAST_SLICE:-}"
  echo "  passed_slices=${PASSED_SLICES:-}"
  echo "  plan_slices=${SLICES[*]}"
  exit 0
fi

echo "wish-orchestrate: host=$CWD spec=$SPEC_ID correlation=$CORRELATION_ID slices=${SLICES[*]} effort=$EFFORT" >&2

enforce_prior_falsify
load_state

idx=0
n=${#SLICES[@]}
dispatched=0
for sid in "${SLICES[@]}"; do
  if slice_already_passed "$sid" && [[ "$FORCE_SLICE" != "1" ]]; then
    echo "wish-orchestrate: skip slice=$sid (already PASSED; use --force-slice to redo)" >&2
    idx=$((idx + 1))
    continue
  fi

  # Per-slice dispatch lock (nested under spec flock)
  SLICE_LOCK="$LOG_DIR/dispatch-lock-${SPEC_ID}-${sid}.lock"
  exec 8>"$SLICE_LOCK"
  if ! flock -n 8; then
    die "slice lock held: $SPEC_ID/$sid (another dispatch in progress)"
  fi

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
    flock -u 8
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

  # Best-effort journey sync (non-fatal)
  if [[ -f "$PLUGIN_ROOT/scripts/wish-journey.sh" ]]; then
    bash "$PLUGIN_ROOT/scripts/wish-journey.sh" --cwd "$CWD" --spec "$SPEC_ID" --set awaiting-falsify >/dev/null 2>&1 || true
  fi
  dispatched=1

  echo "wish-orchestrate: slice=$sid dispatched run_id=$RUN_ID correlation=$CORRELATION_ID" >&2
  echo "wish-orchestrate: NEXT — make record-falsify LOG_DIR=$LOG_DIR RUN_ID=$RUN_ID SLICE=$sid -- <falsify-cmd>" >&2
  echo "wish-orchestrate: then: make require-falsify LOG_DIR=$LOG_DIR RUN_ID=$RUN_ID" >&2

  flock -u 8
  idx=$((idx + 1))
  if [[ "$idx" -lt "$n" ]]; then
    echo "wish-orchestrate: stopping before next slice (falsify gate). Re-run after structured PASS." >&2
    echo "wish-orchestrate: tip: wish-orchestrate --cwd … --spec $SPEC_ID --slice ${SLICES[$idx]}" >&2
    exit 3
  fi
done

if [[ "$dispatched" -eq 0 ]]; then
  echo "wish-orchestrate: nothing to dispatch (all requested slices already PASSED or dry-run skips)." >&2
  echo "wish-orchestrate: Agent Verify + human-acceptance-pack next (not Codex; not Deploy)." >&2
  exit 0
fi

echo "wish-orchestrate: requested slices dispatched. Structured falsify last run_id=${LAST_RUN_ID:-?} then Agent Verify + human-acceptance-pack (not Codex; not Deploy)." >&2
exit 0
