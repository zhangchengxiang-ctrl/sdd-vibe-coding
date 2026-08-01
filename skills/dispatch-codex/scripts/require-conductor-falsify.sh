#!/usr/bin/env bash
# Conductor post-dispatch gate: maker ≠ grader requires a falsify artifact.
#
# Usage:
#   bash …/require-conductor-falsify.sh --log-dir DIR [--run-id ID]
#   # or: --file PATH
#
# Looks for:
#   <log-dir>/<run-id>_falsify.log
#   <log-dir>/conductor-falsify-*.log (mtime within 2h if no run-id)
set -euo pipefail

LOG_DIR=""
RUN_ID=""
FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$FILE" ]]; then
  if [[ -s "$FILE" ]]; then
    echo "require-conductor-falsify: ok ($FILE)"
    exit 0
  fi
  echo "require-conductor-falsify: FAIL empty/missing $FILE" >&2
  exit 1
fi

[[ -n "$LOG_DIR" ]] || { echo "need --log-dir or --file" >&2; exit 2; }
[[ -d "$LOG_DIR" ]] || { echo "log-dir missing: $LOG_DIR" >&2; exit 1; }

if [[ -n "$RUN_ID" ]]; then
  f="$LOG_DIR/${RUN_ID}_falsify.log"
  if [[ -s "$f" ]]; then
    echo "require-conductor-falsify: ok ($f)"
    exit 0
  fi
  echo "require-conductor-falsify: FAIL missing $f (run ≥1 falsify; tee output here)" >&2
  exit 1
fi

# recent conductor-falsify-*
shopt -s nullglob
found=0
now=$(date +%s)
for f in "$LOG_DIR"/conductor-falsify-*.log "$LOG_DIR"/*_falsify.log; do
  [[ -s "$f" ]] || continue
  mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
  if (( now - mt < 7200 )); then
    echo "require-conductor-falsify: ok ($f)"
    found=1
    break
  fi
done
shopt -u nullglob

if [[ "$found" == "1" ]]; then
  exit 0
fi
echo "require-conductor-falsify: FAIL no recent *_falsify.log under $LOG_DIR" >&2
echo "  After Codex returns, run ≥1 falsify command and tee to e.g. \$LOG_DIR/\${RUN_ID}_falsify.log" >&2
exit 1
