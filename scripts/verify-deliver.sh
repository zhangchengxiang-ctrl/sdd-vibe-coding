#!/usr/bin/env bash
# Verify / Deploy close gate: replay the Oracles, then check the claim.
#
# Usage:
#   bash scripts/verify-deliver.sh <host-root> <spec-id>
#   make verify-deliver HOST=/path SPEC=id
#
# ship.sh shipped a full increment before anything required it to run: this path used to be
# check_spec alone, so red-green replay was advisory. The replay comes FIRST here — it writes
# the evidence check_spec --closing then requires — and it runs fresh, never --resume: the
# evidence file lives in the tree being judged, so reading it is not the same as replaying.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -lt 2 ]]; then
  echo "usage: verify-deliver.sh <host-root> <spec-id>" >&2
  exit 2
fi
HOST="$(cd "$1" && pwd)"
SPEC="$2"
SHIP="$ROOT/skills/dispatch-codex/scripts/ship.sh"

# The baseline is the tree this Spec's work started from: the oldest dispatch meta that names
# this Spec and recorded a base_sha. Picking the newest would compare the change against
# itself once a second dispatch had landed.
# The baseline is the tree this Spec's work started from: the oldest dispatch meta that names
# this Spec and recorded a base_sha. Picking the newest would compare the change against itself
# once a second dispatch had landed.
#
# A meta is a text file in a tree the implementer can write, so it is not custody on its own:
# require the run it claims to describe to have left a jsonl carrying turn.completed. Forging
# the baseline now means forging a Codex transcript too. That is a higher wall, not a proof —
# the honest limit is stated in ship.sh's header.
meta=""
for d in "$HOST/.codex-dispatch-logs"; do
  [[ -d "$d" ]] || continue
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    grep -qx "spec=$SPEC" "$f" 2>/dev/null || continue
    grep -q '^base_sha=' "$f" 2>/dev/null || continue
    rid="$(sed -n 's/^run_id=//p' "$f" | head -1)"
    jsonl="$d/${rid}.jsonl"
    if [[ -z "$rid" || ! -s "$jsonl" ]] || ! grep -q 'turn\.completed' "$jsonl" 2>/dev/null; then
      echo "verify-deliver: skipping $(basename "$f") — no completed jsonl for run_id=${rid:-?}" >&2
      continue
    fi
    meta="$f"; break
  done < <(ls -tr "$d"/*.meta.txt 2>/dev/null)
done

echo "== verify-deliver: replay Oracles (ship.sh) =="
if [[ -n "$meta" ]]; then
  echo "verify-deliver: baseline from $(basename "$meta")"
  bash "$SHIP" --host "$HOST" --spec "$SPEC" --from-meta "$meta"
  st=$?
  if [[ "$st" -ne 0 ]]; then
    echo "verify-deliver: replay failed (exit $st) — a Spec does not close on a command that" >&2
    echo "  was never RED without the change, or that fails with it. Fix the Oracle or the" >&2
    echo "  implementation; do not close around this." >&2
    exit "$st"
  fi
else
  echo "verify-deliver: WARN no .codex-dispatch-logs meta names spec=$SPEC with a base_sha —" >&2
  echo "  nothing records which tree predates this work, so no replay ran. check_spec --closing" >&2
  echo "  will refuse unless run.md carries the user-explicit self-written override." >&2
fi

echo "== verify-deliver: check_spec --closing =="
python3 "$ROOT/skills/spec/scripts/check_spec.py" \
  "$HOST" "$SPEC" --skip-agents --closing
st=$?
[[ "$st" -eq 0 ]] || exit "$st"

echo "verify-deliver: ok"
