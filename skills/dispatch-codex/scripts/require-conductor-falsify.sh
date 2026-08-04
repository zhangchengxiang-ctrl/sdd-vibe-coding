#!/usr/bin/env bash
# Conductor post-dispatch gate: maker ≠ grader requires a structured falsify artifact.
#
# Usage:
#   bash …/require-conductor-falsify.sh --log-dir DIR [--run-id ID]
#   # or: --file PATH
#
# Looks for:
#   <log-dir>/<run-id>_falsify.log
#   <log-dir>/conductor-falsify-*.log (mtime within 2h if no run-id)
#
# Structured attestation (default on) — see references/falsify-attestation.md:
#   COMMAND: <non-empty>
#   EXIT_CODE: <int>   # PASS requires 0
#   VERDICT: … PASS
#   If ARTIFACT: present → ARTIFACT_SHA256 required (non-empty, not missing-file)
#
# SKIP_FALSIFY_VERDICT=1 — existence only (maintainer; never in user sessions)
# SKIP_STRUCTURED_FALSIFY=1 — verdict only, skip COMMAND/EXIT_CODE (migration)
set -euo pipefail

LOG_DIR=""
RUN_ID=""
FILE=""
REQUIRE_VERDICT=1
REQUIRE_STRUCTURED=1
if [[ "${SKIP_FALSIFY_VERDICT:-0}" == "1" ]]; then
  REQUIRE_VERDICT=0
  REQUIRE_STRUCTURED=0
fi
if [[ "${SKIP_STRUCTURED_FALSIFY:-0}" == "1" ]]; then
  REQUIRE_STRUCTURED=0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    --require-verdict) REQUIRE_VERDICT=1; shift ;;
    --no-verdict) REQUIRE_VERDICT=0; REQUIRE_STRUCTURED=0; shift ;;
    --no-structured) REQUIRE_STRUCTURED=0; shift ;;
    -h|--help)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown: $1" >&2; exit 2 ;;
  esac
done

field_value() {
  local f="$1" key="$2"
  grep -Ei "^[[:space:]]*${key}:[[:space:]]*" "$f" | head -1 \
    | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//I" | sed -E 's/[[:space:]]+$//'
}

check_structured() {
  local f="$1"
  if [[ "$REQUIRE_STRUCTURED" != "1" ]]; then
    return 0
  fi
  local cmd ec
  cmd="$(field_value "$f" COMMAND)"
  if [[ -z "$cmd" ]]; then
    echo "require-conductor-falsify: FAIL $f missing COMMAND: (use record-conductor-falsify.sh)" >&2
    return 1
  fi
  ec="$(field_value "$f" EXIT_CODE)"
  if [[ ! "$ec" =~ ^[0-9]+$ ]]; then
    echo "require-conductor-falsify: FAIL $f missing/invalid EXIT_CODE:" >&2
    return 1
  fi
  local art sha
  art="$(field_value "$f" ARTIFACT)"
  if [[ -n "$art" ]]; then
    sha="$(field_value "$f" ARTIFACT_SHA256)"
    if [[ -z "$sha" || "$sha" == "missing-file" ]]; then
      echo "require-conductor-falsify: FAIL $f has ARTIFACT but missing ARTIFACT_SHA256" >&2
      return 1
    fi
  fi
  if grep -Eiq '^[[:space:]]*VERDICT:[[:space:]]*.*PASS' "$f"; then
    if [[ "$ec" != "0" ]]; then
      echo "require-conductor-falsify: FAIL $f VERDICT PASS but EXIT_CODE=$ec (must be 0)" >&2
      return 1
    fi
  fi
  return 0
}

check_verdict() {
  local f="$1"
  if [[ "$REQUIRE_VERDICT" != "1" ]]; then
    return 0
  fi
  if ! check_structured "$f"; then
    return 1
  fi
  if grep -Eiq '^[[:space:]]*VERDICT:[[:space:]]*.*PASS' "$f"; then
    return 0
  fi
  if grep -Eiq '^[[:space:]]*VERDICT:[[:space:]]*.*FAIL' "$f"; then
    echo "require-conductor-falsify: FAIL $f has VERDICT: FAIL (repair before next slice)" >&2
    return 1
  fi
  echo "require-conductor-falsify: FAIL $f missing 'VERDICT: PASS' line" >&2
  echo "  Prefer: make record-falsify … -- <cmd>  then require-falsify" >&2
  return 1
}

if [[ -n "$FILE" ]]; then
  if [[ -s "$FILE" ]] && check_verdict "$FILE"; then
    echo "require-conductor-falsify: ok ($FILE)"
    exit 0
  fi
  if [[ ! -s "$FILE" ]]; then
    echo "require-conductor-falsify: FAIL empty/missing $FILE" >&2
  fi
  exit 1
fi

[[ -n "$LOG_DIR" ]] || { echo "need --log-dir or --file" >&2; exit 2; }
[[ -d "$LOG_DIR" ]] || { echo "log-dir missing: $LOG_DIR" >&2; exit 1; }

if [[ -n "$RUN_ID" ]]; then
  f="$LOG_DIR/${RUN_ID}_falsify.log"
  if [[ -s "$f" ]] && check_verdict "$f"; then
    echo "require-conductor-falsify: ok ($f)"
    exit 0
  fi
  if [[ ! -s "$f" ]]; then
    echo "require-conductor-falsify: FAIL missing $f (run record-conductor-falsify.sh)" >&2
  fi
  exit 1
fi

shopt -s nullglob
found=0
now=$(date +%s)
for f in "$LOG_DIR"/conductor-falsify-*.log "$LOG_DIR"/*_falsify.log; do
  [[ -s "$f" ]] || continue
  mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
  if (( now - mt < 7200 )); then
    if check_verdict "$f"; then
      echo "require-conductor-falsify: ok ($f)"
      found=1
      break
    fi
  fi
done
shopt -u nullglob

if [[ "$found" == "1" ]]; then
  exit 0
fi
echo "require-conductor-falsify: FAIL no recent *_falsify.log with structured VERDICT: PASS under $LOG_DIR" >&2
echo "  After Codex returns: make record-falsify LOG_DIR=… RUN_ID=… SLICE=… -- <falsify-cmd>" >&2
exit 1
