#!/usr/bin/env bash
# Run one conductor falsify command and write a structured attestation log.
#
# Usage:
#   bash record-conductor-falsify.sh \
#     --log-dir DIR --run-id ID [--slice S1] [--artifact PATH] -- <command…>
#
# Writes: <log-dir>/<run-id>_falsify.log
# Exit code: same as the falsify command (PASS only when command exits 0).
set -euo pipefail

LOG_DIR=""
RUN_ID=""
SLICE=""
ARTIFACT=""
CWD=""

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --slice) SLICE="${2:-}"; shift 2 ;;
    --artifact) ARTIFACT="${2:-}"; shift 2 ;;
    --cwd) CWD="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *)
      if [[ -z "$LOG_DIR" && -d "$1" ]]; then
        LOG_DIR="$1"; shift
      else
        break
      fi
      ;;
  esac
done

[[ -n "$LOG_DIR" ]] || { echo "record-conductor-falsify: --log-dir required" >&2; exit 2; }
[[ -n "$RUN_ID" ]] || { echo "record-conductor-falsify: --run-id required" >&2; exit 2; }
[[ $# -gt 0 ]] || { echo "record-conductor-falsify: command required after --" >&2; exit 2; }

mkdir -p "$LOG_DIR"
OUT="$LOG_DIR/${RUN_ID}_falsify.log"
CMD_DISPLAY="$*"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ -n "$CWD" ]]; then
  [[ -d "$CWD" ]] || { echo "record-conductor-falsify: --cwd not a dir: $CWD" >&2; exit 2; }
  cd "$CWD"
fi

set +e
OUTPUT="$("$@" 2>&1)"
EC=$?
set -e

{
  printf 'COMMAND: %s\n' "$CMD_DISPLAY"
  printf 'EXIT_CODE: %s\n' "$EC"
  [[ -n "$SLICE" ]] && printf 'SLICE: %s\n' "$SLICE"
  printf 'RUN_ID: %s\n' "$RUN_ID"
  printf 'RECORDED_AT: %s\n' "$TS"
  if [[ -n "$ARTIFACT" ]]; then
    printf 'ARTIFACT: %s\n' "$ARTIFACT"
    if [[ -f "$ARTIFACT" ]]; then
      if command -v sha256sum >/dev/null 2>&1; then
        printf 'ARTIFACT_SHA256: %s\n' "$(sha256sum "$ARTIFACT" | awk '{print $1}')"
      elif command -v shasum >/dev/null 2>&1; then
        printf 'ARTIFACT_SHA256: %s\n' "$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')"
      else
        printf 'ARTIFACT_SHA256: unavailable\n'
      fi
    else
      printf 'ARTIFACT_SHA256: missing-file\n'
    fi
  fi
  printf '%s\n' '--- stdout/stderr ---'
  printf '%s\n' "$OUTPUT"
  if [[ "$EC" -eq 0 ]]; then
    printf 'VERDICT: %s PASS\n' "${SLICE:-ok}"
  else
    printf 'VERDICT: %s FAIL\n' "${SLICE:-ok}"
  fi
} >"$OUT"

echo "record-conductor-falsify: wrote $OUT (exit=$EC)" >&2
exit "$EC"
