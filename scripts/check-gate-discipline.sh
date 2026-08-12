#!/usr/bin/env bash
# PR gate discipline: changing a gate without a reproducible probe is FAIL.
# Probe = scripts/fixtures/gate-cases.tsv (preferred) or scripts/gate-cases-runner.sh.
# Rot non-increase is enforced separately by rot-meter.sh.
#
# Usage:
#   bash scripts/check-gate-discipline.sh
#   GATE_DISCIPLINE_BASE=origin/main bash scripts/check-gate-discipline.sh
#
# No base ref / empty diff → skip (exit 0). Local `make public-gates` stays green.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE="${GATE_DISCIPLINE_BASE:-}"
if [[ -z "$BASE" ]]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE=origin/main
  elif git rev-parse --verify main >/dev/null 2>&1; then
    BASE=main
  else
    echo "== gate-discipline SKIP (no base ref) =="
    exit 0
  fi
fi

if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "== gate-discipline SKIP (missing $BASE) =="
  exit 0
fi

mapfile -t changed < <(git diff --name-only "$BASE"...HEAD 2>/dev/null || true)
if [[ ${#changed[@]} -eq 0 ]]; then
  echo "== gate-discipline SKIP (empty diff vs $BASE) =="
  exit 0
fi

is_gate() {
  local f="$1"
  [[ "$f" == skills/spec/scripts/check_spec.py ]] && return 0
  [[ "$f" == scripts/verify-deliver.sh ]] && return 0
  [[ "$f" == scripts/close-spec.sh ]] && return 0
  [[ "$f" == scripts/orphan-refs.sh ]] && return 0
  [[ "$f" == scripts/check-gate-discipline.sh ]] && return 0
  [[ "$f" =~ ^templates/\.cursor/rules/.*\.mdc$ ]] && return 0
  [[ "$f" =~ ^scripts/.*gate.*\.sh$ ]] && return 0
  [[ "$f" =~ ^skills/dispatch-codex/scripts/require-.*\.sh$ ]] && return 0
  return 1
}

is_probe() {
  local f="$1"
  [[ "$f" == scripts/fixtures/gate-cases.tsv ]] && return 0
  [[ "$f" == scripts/gate-cases-runner.sh ]] && return 0
  return 1
}

gate_hit=0
probe_hit=0
for f in "${changed[@]}"; do
  is_gate "$f" && gate_hit=1
  is_probe "$f" && probe_hit=1
done

echo "== gate-discipline base=$BASE gate_hit=$gate_hit probe_hit=$probe_hit =="
if [[ "$gate_hit" -eq 1 && "$probe_hit" -eq 0 ]]; then
  echo "FAIL: gate/rule change without probe update (gate-cases.tsv or gate-cases-runner.sh)" >&2
  echo "Law: ARCHITECTURE.md §维护铁律 (4)" >&2
  exit 1
fi
echo "OK gate-discipline"
exit 0
