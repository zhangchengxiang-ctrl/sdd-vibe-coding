#!/usr/bin/env bash
# Wish orchestration: pack A→D (272K) → edit-wave Codex Build → verify-wave falsify.
#
# Usage:
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID [--slice S1] [--effort medium|high]
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --list
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --status
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --pack-only --slice S1
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --force-slice S1
#   bash wish-orchestrate.sh --cwd HOST --spec SPEC_ID --parallel 2
#
# Does NOT run Verify / human acceptance (钉 3). Machine loop = pack→edit-wave→structured falsify.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wish-orchestrate.sh --cwd DIR --spec ID [options]

Required:
  --cwd DIR       Host repo root
  --spec ID       Spec id under SDD docs/specs/

Options:
  --slice ID      Only the dispatch unit containing this slice (S1 or S1,S2)
  --force-slice   Re-dispatch even if slice already in PASSED_SLICES
  --effort LVL    medium|high (default: medium)
  --parallel N    Max Codex procs in one edit-wave (1–4, default 2)
  --list          Print acceptance slice ids and exit
  --units         Print packed dispatch units and exit
  --status        Print wish state and exit
  --pack-only     Emit Context Pack for --slice / first pending unit (no Codex)
  --dry-run       Print dispatch commands; do not run Codex
  -h, --help

Exit codes:
  0  last requested edit-wave dispatched or all already passed
  3  edit-wave dispatched; structured falsify PASS required before next wave
  2  usage / hard failure
EOF
}

die() { echo "wish-orchestrate: $*" >&2; exit 2; }

CWD=""
SPEC_ID=""
SLICE_ID=""
EFFORT="${CODEX_DISPATCH_EFFORT:-medium}"
PARALLEL="${WISH_ORCHESTRATE_PARALLEL:-2}"
LIST=0
UNITS=0
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
    --parallel) PARALLEL="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --units) UNITS=1; shift ;;
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
[[ "$PARALLEL" =~ ^[1-4]$ ]] || die "--parallel must be 1–4"

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PACK_PY="$PLUGIN_ROOT/skills/dispatch-codex/scripts/build_context_pack.py"
PACK_UNITS="$PLUGIN_ROOT/skills/dispatch-codex/scripts/pack_dispatch_units.py"
SCHEDULE="$PLUGIN_ROOT/skills/dispatch-codex/scripts/schedule_waves.py"
DISPATCH="$PLUGIN_ROOT/skills/dispatch-codex/scripts/codex-dispatch.sh"
DETECT="$PLUGIN_ROOT/skills/dispatch-codex/scripts/detect_compact.py"
REQUIRE_FALSIFY="$PLUGIN_ROOT/skills/dispatch-codex/scripts/require-conductor-falsify.sh"
[[ -f "$PACK_PY" ]] || die "missing $PACK_PY"
[[ -f "$PACK_UNITS" ]] || die "missing $PACK_UNITS"
[[ -f "$DISPATCH" ]] || die "missing $DISPATCH"
[[ -f "$REQUIRE_FALSIFY" ]] || die "missing $REQUIRE_FALSIFY"

if [[ "$LIST" == "1" ]]; then
  python3 "$PACK_PY" "$CWD" "$SPEC_ID" --list
  exit 0
fi

if [[ "$UNITS" == "1" ]]; then
  python3 "$PACK_UNITS" "$CWD" "$SPEC_ID" --list
  exit 0
fi

mapfile -t SLICES < <(python3 "$PACK_PY" "$CWD" "$SPEC_ID" --list)
[[ ${#SLICES[@]} -gt 0 ]] || die "no slices in plan.md for $SPEC_ID"

GRAPH_JSON="$(python3 "$PACK_UNITS" "$CWD" "$SPEC_ID" --json)" || die "pack_dispatch_units failed"
WAVES_JSON="$(printf '%s\n' "$GRAPH_JSON" | python3 "$SCHEDULE" - --edit-parallel "$PARALLEL")" \
  || die "schedule_waves failed"

LOG_DIR="${CODEX_DISPATCH_LOG_DIR:-$CWD/.codex-dispatch-logs}"
mkdir -p "$LOG_DIR"
PACK_DIR="$LOG_DIR/context-packs"
mkdir -p "$PACK_DIR"
STATE_FILE="$LOG_DIR/wish-state-${SPEC_ID}.env"
LOCK_FILE="$LOG_DIR/wish-lock-${SPEC_ID}.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  die "lock held: another wish-orchestrate for spec=$SPEC_ID (lock=$LOCK_FILE)"
fi

load_state() {
  AWAITING_FALSIFY=0
  LAST_RUN_ID=""
  LAST_RUN_IDS=""
  LAST_SLICE=""
  LAST_DISPATCH=""
  PASSED_SLICES=""
  PASSED_UNITS=""
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
LAST_RUN_IDS='$LAST_RUN_IDS'
LAST_SLICE=$LAST_SLICE
LAST_DISPATCH='$LAST_DISPATCH'
PASSED_SLICES='$PASSED_SLICES'
PASSED_UNITS='$PASSED_UNITS'
CORRELATION_ID=$CORRELATION_ID
SPEC_ID=$SPEC_ID
EOF
}

mark_slice_passed() {
  local sid="$1"
  case " $PASSED_SLICES " in
    *" $sid "*) ;;
    *) PASSED_SLICES="${PASSED_SLICES:+$PASSED_SLICES }$sid" ;;
  esac
}

mark_unit_passed() {
  local uid="$1"
  case " $PASSED_UNITS " in
    *" $uid "*) ;;
    *) PASSED_UNITS="${PASSED_UNITS:+$PASSED_UNITS }$uid" ;;
  esac
}

slice_already_passed() {
  local sid="$1"
  case " $PASSED_SLICES " in
    *" $sid "*) return 0 ;;
    *) return 1 ;;
  esac
}

unit_already_passed() {
  local uid="$1"
  case " $PASSED_UNITS " in
    *" $uid "*) return 0 ;;
    *) return 1 ;;
  esac
}

unit_slices() {
  local uid="$1"
  python3 - "$GRAPH_JSON" "$uid" <<'PY'
import json, sys
g = json.loads(sys.argv[1])
uid = sys.argv[2]
for u in g["units"]:
    if u["id"] == uid:
        print(" ".join(u["slices"]))
        break
PY
}

unit_field() {
  local uid="$1" field="$2"
  python3 - "$GRAPH_JSON" "$uid" "$field" <<'PY'
import json, sys
g = json.loads(sys.argv[1])
uid, field = sys.argv[2], sys.argv[3]
for u in g["units"]:
    if u["id"] == uid:
        v = u.get(field)
        if isinstance(v, list):
            print(",".join(str(x) for x in v))
        elif v is True:
            print("1")
        elif v is False or v is None:
            print("")
        else:
            print(v)
        break
PY
}

all_unit_ids() {
  python3 - "$GRAPH_JSON" <<'PY'
import json, sys
g = json.loads(sys.argv[1])
print(" ".join(u["id"] for u in g["units"]))
PY
}

edit_waves() {
  python3 - "$WAVES_JSON" <<'PY'
import json, sys
w = json.loads(sys.argv[1])
for wave in w.get("edit_waves") or []:
    print(" ".join(wave))
PY
}

enforce_prior_falsify() {
  if [[ "${SKIP_FALSIFY_GATE:-0}" == "1" ]]; then
    echo "wish-orchestrate: WARN SKIP_FALSIFY_GATE=1 — maintainer-only; never in user sessions" >&2
    if [[ -n "${LAST_DISPATCH:-}" ]]; then
      for uid in $LAST_DISPATCH; do
        mark_unit_passed "$uid"
        for sid in $(unit_slices "$uid"); do
          mark_slice_passed "$sid"
        done
      done
    elif [[ -n "${LAST_SLICE:-}" ]]; then
      mark_slice_passed "$LAST_SLICE"
    fi
    AWAITING_FALSIFY=0
    LAST_RUN_IDS=""
    save_state
    return 0
  fi
  load_state
  if [[ "${AWAITING_FALSIFY:-0}" != "1" ]]; then
    return 0
  fi
  local ids="${LAST_RUN_IDS:-$LAST_RUN_ID}"
  [[ -n "$ids" ]] || return 0
  echo "wish-orchestrate: prior dispatch ${LAST_DISPATCH:-$LAST_SLICE} awaits structured falsify ($ids)" >&2
  local rid
  for rid in $ids; do
    if ! bash "$REQUIRE_FALSIFY" --log-dir "$LOG_DIR" --run-id "$rid"; then
      die "falsify gate blocked: make record-falsify LOG_DIR=$LOG_DIR RUN_ID=$rid SLICE=${LAST_SLICE:-S?} -- <cmd>"
    fi
  done
  if [[ -n "${LAST_DISPATCH:-}" ]]; then
    for uid in $LAST_DISPATCH; do
      mark_unit_passed "$uid"
      for sid in $(unit_slices "$uid"); do
        mark_slice_passed "$sid"
      done
    done
  elif [[ -n "${LAST_SLICE:-}" ]]; then
    mark_slice_passed "$LAST_SLICE"
  fi
  AWAITING_FALSIFY=0
  LAST_RUN_IDS=""
  save_state
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
  echo "  last_run_ids=${LAST_RUN_IDS:-}"
  echo "  last_slice=${LAST_SLICE:-}"
  echo "  last_dispatch=${LAST_DISPATCH:-}"
  echo "  passed_slices=${PASSED_SLICES:-}"
  echo "  passed_units=${PASSED_UNITS:-}"
  echo "  plan_slices=${SLICES[*]}"
  echo "  dispatch_units=$(all_unit_ids)"
  exit 0
fi

echo "wish-orchestrate: host=$CWD spec=$SPEC_ID correlation=$CORRELATION_ID effort=$EFFORT parallel=$PARALLEL" >&2
echo "wish-orchestrate: units=$(all_unit_ids)" >&2

incomplete="$(python3 - "$GRAPH_JSON" <<'PY'
import json, sys
g = json.loads(sys.argv[1])
print(" ".join(g.get("incomplete_allowlist") or []))
PY
)"
too_large="$(python3 - "$GRAPH_JSON" <<'PY'
import json, sys
g = json.loads(sys.argv[1])
print(" ".join(g.get("too_large") or []))
PY
)"
if [[ -n "$incomplete" && "$PACK_ONLY" != "1" && "$DRY_RUN" != "1" ]]; then
  die "incomplete allowlist on units: $incomplete (plan.md 触及路径 required)"
fi
if [[ -n "$too_large" && "$PACK_ONLY" != "1" && "$DRY_RUN" != "1" ]]; then
  die "units exceed 180K window: $too_large — split allowlist / Spec; do not Goal-hard-撑"
fi

enforce_prior_falsify
load_state

# Resolve target unit ids for this invoke
TARGET_UNITS=()
if [[ -n "$SLICE_ID" ]]; then
  first="$(echo "$SLICE_ID" | tr ',' ' ' | awk '{print $1}')"
  uid="$(python3 "$PACK_UNITS" "$CWD" "$SPEC_ID" --slice "$first" | awk '{print $1}')"
  [[ -n "$uid" ]] || die "no dispatch unit contains slice $first"
  TARGET_UNITS=("$uid")
else
  while IFS= read -r wave; do
    [[ -n "$wave" ]] || continue
    pending=()
    for uid in $wave; do
      skip=1
      for sid in $(unit_slices "$uid"); do
        if ! slice_already_passed "$sid" || [[ "$FORCE_SLICE" == "1" ]]; then
          skip=0
          break
        fi
      done
      if [[ "$skip" == "1" ]] && unit_already_passed "$uid" && [[ "$FORCE_SLICE" != "1" ]]; then
        echo "wish-orchestrate: skip unit=$uid (already PASSED)" >&2
        continue
      fi
      if [[ "$skip" == "1" && "$FORCE_SLICE" != "1" ]]; then
        echo "wish-orchestrate: skip unit=$uid (slices already PASSED)" >&2
        continue
      fi
      pending+=("$uid")
    done
    if [[ ${#pending[@]} -gt 0 ]]; then
      TARGET_UNITS=("${pending[@]}")
      break
    fi
  done < <(edit_waves)
fi

if [[ ${#TARGET_UNITS[@]} -eq 0 ]]; then
  echo "wish-orchestrate: nothing to dispatch (all requested units already PASSED or dry-run skips)." >&2
  echo "wish-orchestrate: Agent Verify next (machine close if no-UI; else human-acceptance-pack). Not Deploy." >&2
  exit 0
fi

if [[ "$PACK_ONLY" == "1" ]]; then
  uid="${TARGET_UNITS[0]}"
  members="$(unit_slices "$uid")"
  csv="$(echo "$members" | tr ' ' ',')"
  python3 "$PACK_PY" "$CWD" "$SPEC_ID" "$csv"
  exit 0
fi

RUN_IDS=()
DISPATCHED_UIDS=()
declare -A UNIT_PACK_FILE
declare -A UNIT_SLICE_CSV

for uid in "${TARGET_UNITS[@]}"; do
  members="$(unit_slices "$uid")"
  csv="$(echo "$members" | tr ' ' ',')"
  allow="$(unit_field "$uid" writes)"
  if [[ -z "$allow" && "$DRY_RUN" != "1" ]]; then
    die "unit $uid has empty allowlist"
  fi
  echo "wish-orchestrate: === pack unit=$uid slices=$csv ===" >&2
  pack_file="$PACK_DIR/${SPEC_ID}_${uid}_$(date -u +%Y%m%dT%H%M%SZ).txt"
  if ! python3 "$PACK_PY" "$CWD" "$SPEC_ID" "$csv" >"$pack_file"; then
    die "context pack failed for unit $uid"
  fi
  echo "wish-orchestrate: pack=$pack_file" >&2
  UNIT_PACK_FILE["$uid"]="$pack_file"
  UNIT_SLICE_CSV["$uid"]="$csv"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY-RUN: would dispatch build unit=$uid slices=$csv with pack $pack_file" >&2
    DISPATCHED_UIDS+=("$uid")
  fi
done

# --- Parallel isolation: one git worktree per unit, pinned to one SHA ---------
# Multiple `codex exec` processes must never share one working tree. Before this,
# every parallel arm got --cwd "$CWD"; the per-unit flock only stopped the same
# unit being dispatched twice and isolated nothing between different units.
declare -A UNIT_CWD=()
WT_ROOT=""
if [[ "$DRY_RUN" != "1" && "${#TARGET_UNITS[@]}" -gt 1 ]]; then
  git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 \
    || die "parallel dispatch requires a git repo at $CWD (worktree isolation)"
  BASE_SHA="$(git -C "$CWD" rev-parse HEAD)"
  # Include a hash of the absolute path: two repos with the same basename must not
  # share a worktree root (and must never reuse each other's trees).
  CWD_TAG="$(printf '%s' "$CWD" | cksum | cut -d' ' -f1)"
  WT_ROOT="${WISH_WORKTREE_ROOT:-${TMPDIR:-/tmp}/sdd-wish-wt}/$(basename "$CWD")-${CWD_TAG}-${SPEC_ID}"
  mkdir -p "$WT_ROOT"
  for uid in "${TARGET_UNITS[@]}"; do
    wt="$WT_ROOT/$uid"
    if [[ -e "$wt/.git" ]]; then
      # Reuse only a clean tree. A leftover dirty worktree means the previous wave was
      # never merged; silently building on top of it would hide that.
      # Ignore the dep symlinks this script created itself; everything else is real work.
      wt_dirty="$(git -C "$wt" status --porcelain 2>/dev/null || true)"
      read -r -a _links <<<"${WISH_WORKTREE_LINK:-node_modules}"
      for link in "${_links[@]}"; do
        wt_dirty="$(printf '%s\n' "$wt_dirty" | grep -vF -- "$link" || true)"
      done
      if [[ -n "$(printf '%s' "$wt_dirty" | tr -d '[:space:]')" ]]; then
        die "worktree $wt still holds unmerged changes from an earlier wave — merge it, or: git -C $CWD worktree remove --force $wt"
      fi
      git -C "$wt" checkout -q --detach "$BASE_SHA" 2>/dev/null \
        || die "cannot reset worktree $wt to $BASE_SHA"
    else
      rm -rf "$wt"
      git -C "$CWD" worktree add -q --detach "$wt" "$BASE_SHA" \
        || die "git worktree add failed for unit $uid"
      # Uninstalled deps make a fresh worktree untestable; link them read-only.
      # Split on whitespace only — never glob.
      read -r -a _links <<<"${WISH_WORKTREE_LINK:-node_modules}"
      for link in "${_links[@]}"; do
        if [[ -e "$CWD/$link" && ! -e "$wt/$link" ]]; then ln -s "$CWD/$link" "$wt/$link"; fi
      done
    fi
    UNIT_CWD["$uid"]="$wt"
  done
  echo "wish-orchestrate: ${#TARGET_UNITS[@]} units → isolated worktrees at ${BASE_SHA:0:12} under $WT_ROOT" >&2
  echo "wish-orchestrate: nothing is auto-merged — the conductor merges." >&2
fi

if [[ "$DRY_RUN" != "1" ]]; then
  pids=()
  uid_by_pid=()
  for uid in "${TARGET_UNITS[@]}"; do
    csv="${UNIT_SLICE_CSV[$uid]}"
    pack_file="${UNIT_PACK_FILE[$uid]}"
    UNIT_LOCK="$LOG_DIR/dispatch-lock-${SPEC_ID}-${uid}.lock"
    rid_file="$LOG_DIR/wish-run-${SPEC_ID}-${uid}.run_id"
    rm -f "$rid_file"
    echo "wish-orchestrate: dispatch unit=$uid slices=$csv parallel=$PARALLEL" >&2
    (
      exec 8>"$UNIT_LOCK"
      flock -n 8 || { echo "wish-orchestrate: unit lock held: $SPEC_ID/$uid" >&2; exit 2; }
      bash "$DISPATCH" \
        --cwd "${UNIT_CWD[$uid]:-$CWD}" \
        --log-dir "$LOG_DIR" \
        --unit build \
        --effort "$EFFORT" \
        --spec "$SPEC_ID" \
        --slice "$csv" \
        --dispatch-id "$uid" \
        --run-id-file "$rid_file" \
        -- "$(cat "$pack_file")" >/dev/null
    ) &
    pids+=("$!")
    uid_by_pid+=("$uid")
  done
  fail=0
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      echo "wish-orchestrate: dispatch failed unit=${uid_by_pid[$i]} pid=${pids[$i]}" >&2
      fail=1
    fi
  done
  # Report isolated trees before failing, so a partial wave is still diagnosable.
  if [[ -n "$WT_ROOT" ]]; then
    echo "wish-orchestrate: isolated results (merge these yourself):" >&2
    for uid in "${TARGET_UNITS[@]}"; do
      wt="${UNIT_CWD[$uid]:-}"
      [[ -n "$wt" ]] || continue
      stat="$(git -C "$wt" --no-pager diff --shortstat 2>/dev/null | sed 's/^ *//')"
      echo "  $uid  ${stat:-(no change)}  $wt" >&2
    done
    echo "wish-orchestrate: cleanup → git -C $CWD worktree remove --force <path> (then worktree prune)" >&2
  fi
  [[ "$fail" == "0" ]] || die "one or more edit-wave dispatches failed"
  for uid in "${TARGET_UNITS[@]}"; do
    rid_file="$LOG_DIR/wish-run-${SPEC_ID}-${uid}.run_id"
    [[ -s "$rid_file" ]] || die "missing RUN_ID file for unit $uid ($rid_file) — dispatch did not report id"
    run_id="$(tr -d '[:space:]' <"$rid_file")"
    [[ -n "$run_id" ]] || die "empty RUN_ID file for unit $uid"
    meta="$LOG_DIR/${run_id}.meta.txt"
    jsonl="$LOG_DIR/${run_id}.jsonl"
    [[ -f "$meta" ]] || die "missing meta for RUN_ID=$run_id"
    if [[ -f "$jsonl" ]]; then
      python3 "$DETECT" --require-turn "$jsonl" >/dev/null \
        || die "Codex turn did not complete cleanly for unit $uid RUN_ID=$run_id"
    fi
    RUN_IDS+=("$run_id")
    DISPATCHED_UIDS+=("$uid")
  done
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "wish-orchestrate: dry-run units=${DISPATCHED_UIDS[*]}" >&2
  exit 0
fi

[[ ${#RUN_IDS[@]} -gt 0 ]] || die "no run_ids recorded"

AWAITING_FALSIFY=1
LAST_RUN_ID="${RUN_IDS[0]}"
LAST_RUN_IDS="${RUN_IDS[*]}"
LAST_DISPATCH="${DISPATCHED_UIDS[*]}"
LAST_SLICE="$(unit_slices "${DISPATCHED_UIDS[0]}" | awk '{print $1}')"
save_state

if [[ -f "$PLUGIN_ROOT/scripts/wish-journey.sh" ]]; then
  bash "$PLUGIN_ROOT/scripts/wish-journey.sh" --cwd "$CWD" --spec "$SPEC_ID" --set awaiting-falsify >/dev/null 2>&1 || true
fi

echo "wish-orchestrate: dispatched units=${DISPATCHED_UIDS[*]} run_ids=${RUN_IDS[*]} correlation=$CORRELATION_ID" >&2
echo "wish-orchestrate: NEXT — verify-wave: make record-falsify LOG_DIR=$LOG_DIR RUN_ID=<id> SLICE=<S*> -- <cmd>" >&2
echo "wish-orchestrate: then: make require-falsify LOG_DIR=$LOG_DIR RUN_ID=<id>  (each run_id)" >&2

# More edit-waves remaining?
remaining=0
while IFS= read -r wave; do
  [[ -n "$wave" ]] || continue
  for uid in $wave; do
    skip=1
    case " ${DISPATCHED_UIDS[*]} " in
      *" $uid "*) continue ;;
    esac
    if unit_already_passed "$uid"; then
      continue
    fi
    for sid in $(unit_slices "$uid"); do
      if ! slice_already_passed "$sid"; then
        skip=0
        break
      fi
    done
    if [[ "$skip" == "0" ]]; then
      remaining=1
      break
    fi
  done
  [[ "$remaining" == "1" ]] && break
done < <(edit_waves)

if [[ "$remaining" == "1" ]]; then
  echo "wish-orchestrate: stopping before next edit-wave (verify-wave falsify gate)." >&2
  exit 3
fi

echo "wish-orchestrate: requested edit-wave dispatched. Structured falsify then Agent Verify (not Codex; not Deploy)." >&2
exit 0
