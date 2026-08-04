#!/usr/bin/env bash
# Wish / delivery journey disk state machine (OpenSpec-inspired clarity; SDD vocab).
#
# Usage:
#   bash scripts/wish-journey.sh --cwd HOST --spec ID --status
#   bash scripts/wish-journey.sh --cwd HOST --spec ID --set PHASE
#   bash scripts/wish-journey.sh --cwd HOST --spec ID --transition PHASE
#   bash scripts/wish-journey.sh --cwd HOST --spec ID --assert write|build|deploy|claim-deliver
#   bash scripts/wish-journey.sh --cwd HOST --spec ID --list-phases
#
# State file: <host>/.sdd/journey/<spec>.env
set -euo pipefail
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/hooks" && pwd)"
# shellcheck disable=SC1091
source "$HOOKS_DIR/lib.sh"

CWD="."
SPEC=""
ACTION=""
TARGET_PHASE=""
FORCE=0

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --spec) SPEC="${2:-}"; shift 2 ;;
    --status) ACTION=status; shift ;;
    --set) ACTION=set; TARGET_PHASE="${2:-}"; shift 2 ;;
    --transition) ACTION=transition; TARGET_PHASE="${2:-}"; shift 2 ;;
    --assert) ACTION=assert; TARGET_PHASE="${2:-}"; shift 2 ;;
    --list-phases) ACTION=list; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

PHASES=(idle design-ready planning building awaiting-falsify verifying repairing awaiting-human-acceptance acceptance-passed blocked)

is_phase() {
  local p="$1" x
  for x in "${PHASES[@]}"; do
    [[ "$x" == "$p" ]] && return 0
  done
  return 1
}

can_transition() {
  local from="$1" to="$2"
  [[ "$FORCE" == "1" ]] && return 0
  [[ "$to" == "blocked" ]] && return 0
  local key="${from}__${to}"
  case "$key" in
    idle__design-ready) return 0 ;;
    design-ready__planning|design-ready__building) return 0 ;;
    planning__building|planning__design-ready) return 0 ;;
    building__awaiting-falsify|building__verifying|building__repairing|building__blocked) return 0 ;;
    awaiting-falsify__building|awaiting-falsify__verifying|awaiting-falsify__repairing|awaiting-falsify__blocked) return 0 ;;
    verifying__awaiting-human-acceptance|verifying__repairing|verifying__blocked) return 0 ;;
    repairing__building|repairing__verifying|repairing__blocked) return 0 ;;
    awaiting-human-acceptance__acceptance-passed|awaiting-human-acceptance__repairing|awaiting-human-acceptance__blocked) return 0 ;;
    acceptance-passed__blocked) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ "$ACTION" == "list" ]]; then
  printf '%s\n' "${PHASES[@]}"
  exit 0
fi

[[ -n "$SPEC" ]] || { echo "wish-journey: --spec required" >&2; exit 2; }
[[ -n "$ACTION" ]] || { echo "wish-journey: need --status|--set|--transition|--assert" >&2; exit 2; }

ROOT="$(sdd_find_root "$CWD")"
DIR="$ROOT/.sdd/journey"
FILE="$DIR/${SPEC}.env"
mkdir -p "$DIR"

load() {
  PHASE=idle
  UPDATED_AT=
  CORRELATION_ID=
  if [[ -f "$FILE" ]]; then
    # shellcheck disable=SC1090
    source "$FILE"
  fi
}

save() {
  cat >"$FILE" <<EOF
PHASE=$PHASE
SPEC_ID=$SPEC
UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CORRELATION_ID=${CORRELATION_ID:-$SPEC-$(date -u +%Y%m%dT%H%M%SZ)}
EOF
}

load

case "$ACTION" in
  status)
    echo "wish-journey:"
    echo "  host=$ROOT"
    echo "  spec=$SPEC"
    echo "  phase=${PHASE:-idle}"
    echo "  updated_at=${UPDATED_AT:-}"
    echo "  correlation_id=${CORRELATION_ID:-}"
    echo "  file=$FILE"
    exit 0
    ;;
  set)
    is_phase "$TARGET_PHASE" || { echo "wish-journey: invalid phase $TARGET_PHASE" >&2; exit 2; }
    PHASE="$TARGET_PHASE"
    save
    echo "wish-journey: set phase=$PHASE ($FILE)"
    # Side-effect: planning/building implies build auth marker convenience
    if [[ "$PHASE" == "planning" || "$PHASE" == "building" ]]; then
      if [[ ! -f "$ROOT/.sdd/authorize.build" ]]; then
        bash "$HOOKS_DIR/authorize.sh" --cwd "$ROOT" --kind build --note "wish-journey:$PHASE" >/dev/null
        echo "wish-journey: ensured .sdd/authorize.build"
      fi
    fi
    exit 0
    ;;
  transition)
    is_phase "$TARGET_PHASE" || { echo "wish-journey: invalid phase $TARGET_PHASE" >&2; exit 2; }
    FROM="${PHASE:-idle}"
    if ! can_transition "$FROM" "$TARGET_PHASE"; then
      echo "wish-journey: illegal transition $FROM -> $TARGET_PHASE (use --force to override)" >&2
      exit 1
    fi
    PHASE="$TARGET_PHASE"
    save
    echo "wish-journey: $FROM -> $PHASE"
    if [[ "$PHASE" == "planning" || "$PHASE" == "building" ]]; then
      if [[ ! -f "$ROOT/.sdd/authorize.build" ]]; then
        bash "$HOOKS_DIR/authorize.sh" --cwd "$ROOT" --kind build --note "wish-journey:$PHASE" >/dev/null
      fi
    fi
    exit 0
    ;;
  assert)
    case "$TARGET_PHASE" in
      write|build)
        if sdd_auth_build_ok "$ROOT" || [[ "${PHASE:-}" =~ ^(planning|building|awaiting-falsify|verifying|repairing)$ ]]; then
          echo "wish-journey: assert $TARGET_PHASE ok (phase=$PHASE)"
          exit 0
        fi
        echo "wish-journey: assert $TARGET_PHASE FAIL (phase=$PHASE; need authorize.build or journey planning+)" >&2
        exit 1
        ;;
      deploy)
        if sdd_auth_deploy_ok "$ROOT"; then
          echo "wish-journey: assert deploy ok"
          exit 0
        fi
        echo "wish-journey: assert deploy FAIL (need .sdd/authorize.deploy-p4 <24h)" >&2
        exit 1
        ;;
      claim-deliver)
        if [[ "${PHASE:-}" == "acceptance-passed" ]] || [[ "${PHASE:-}" == "awaiting-human-acceptance" ]]; then
          # awaiting-human may not claim acceptance-passed; only acceptance-passed or verify-deliver
          if [[ "${PHASE:-}" == "acceptance-passed" ]]; then
            echo "wish-journey: assert claim-deliver ok"
            exit 0
          fi
        fi
        # Also allow if verify-deliver stamp exists in run.md — light check
        if [[ -f "$ROOT/docs/specs/$SPEC/run.md" ]] \
          && grep -q 'verify-deliver: ok' "$ROOT/docs/specs/$SPEC/run.md" 2>/dev/null \
          && [[ "${PHASE:-}" == "awaiting-human-acceptance" || "${PHASE:-}" == "acceptance-passed" || "${PHASE:-}" == "verifying" ]]; then
          echo "wish-journey: assert claim-deliver soft-ok (verify-deliver present; still need human for acceptance-passed)"
          exit 0
        fi
        echo "wish-journey: assert claim-deliver FAIL (phase=$PHASE)" >&2
        exit 1
        ;;
      *)
        echo "wish-journey: unknown assert $TARGET_PHASE" >&2
        exit 2
        ;;
    esac
    ;;
esac
