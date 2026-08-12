#!/usr/bin/env bash
# Rot meter — budget ceiling gate (P0: ceiling = baseline; only forbids growth).
# Usage:
#   bash scripts/rot-meter.sh              # compare to baseline; exit 1 if over
#   bash scripts/rot-meter.sh --write-baseline  # record current as baseline
#   bash scripts/rot-meter.sh --report     # print metrics only (exit 0)
#
# Ceiling may ONLY be lowered over time (ratchet). Never raise without Owner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BASELINE="$ROOT/scripts/rot-baseline.json"
MODE=compare
WRITE=0
for arg in "$@"; do
  case "$arg" in
    --write-baseline) WRITE=1; MODE=write ;;
    --report) MODE=report ;;
  esac
done

# --- metrics (active corpus only; _archive is not budget) ---
skills_bytes=$(find skills -name '*.md' -type f ! -path '*/_archive/*' -print0 | xargs -0 cat 2>/dev/null | wc -c | tr -d ' ')
skills_md_count=$(find skills -name '*.md' -type f ! -path '*/_archive/*' | wc -l | tr -d ' ')
skills_lines=$(find skills -name '*.md' -type f ! -path '*/_archive/*' -print0 | xargs -0 cat 2>/dev/null | wc -l | tr -d ' ')
mdc_count=$(find templates/.cursor/rules -name '*.mdc' -type f 2>/dev/null | wc -l | tr -d ' ')

# per-SKILL.md lines
skill_lines_json="{"
first=1
while IFS= read -r f; do
  n=$(wc -l <"$f" | tr -d ' ')
  rel=${f#./}
  if [[ $first -eq 1 ]]; then first=0; else skill_lines_json+=","; fi
  skill_lines_json+="\"$rel\":$n"
done < <(find skills -name 'SKILL.md' -type f | sort)
skill_lines_json+="}"

# always-on window: entry + gates (or legacy workflow-contract) + wish-delivery if present
entry_lines=$(wc -l <skills/vibe-coding/SKILL.md | tr -d ' ')
gates_file=""
if [[ -f skills/vibe-coding/references/gates.md ]]; then
  gates_file=skills/vibe-coding/references/gates.md
elif [[ -f skills/vibe-coding/references/workflow-contract.md ]]; then
  gates_file=skills/vibe-coding/references/workflow-contract.md
fi
gates_lines=0
[[ -n "$gates_file" ]] && gates_lines=$(wc -l <"$gates_file" | tr -d ' ')
wish_lines=0
[[ -f skills/vibe-coding/references/wish-delivery.md ]] \
  && wish_lines=$(wc -l <skills/vibe-coding/references/wish-delivery.md | tr -d ' ')
always_on_window=$((entry_lines + gates_lines + wish_lines))

# duplicate-definition / orphan counts via sibling scripts (report mode)
dup_hits=0
orphan_hits=0
if [[ -x "$ROOT/scripts/single-definition.sh" ]] || [[ -f "$ROOT/scripts/single-definition.sh" ]]; then
  dup_hits=$(bash "$ROOT/scripts/single-definition.sh" --count 2>/dev/null || echo 0)
fi
if [[ -x "$ROOT/scripts/orphan-refs.sh" ]] || [[ -f "$ROOT/scripts/orphan-refs.sh" ]]; then
  orphan_hits=$(bash "$ROOT/scripts/orphan-refs.sh" --count 2>/dev/null || echo 0)
fi

# ensure numeric
dup_hits=${dup_hits:-0}
orphan_hits=${orphan_hits:-0}
dup_hits=$(echo "$dup_hits" | tr -cd '0-9')
orphan_hits=$(echo "$orphan_hits" | tr -cd '0-9')
[[ -z "$dup_hits" ]] && dup_hits=0
[[ -z "$orphan_hits" ]] && orphan_hits=0

json_out=$(python3 - <<PY
import json
print(json.dumps({
  "skills_bytes": int("$skills_bytes"),
  "skills_md_count": int("$skills_md_count"),
  "skills_lines": int("$skills_lines"),
  "mdc_count": int("$mdc_count"),
  "always_on_window_lines": int("$always_on_window"),
  "entry_lines": int("$entry_lines"),
  "gates_lines": int("$gates_lines"),
  "wish_lines": int("$wish_lines"),
  "duplicate_definition_hits": int("$dup_hits"),
  "orphan_ref_hits": int("$orphan_hits"),
  "skill_md_lines": json.loads('''$skill_lines_json'''),
}, indent=2, ensure_ascii=False))
PY
)

echo "== rot-meter =="
echo "$json_out"

if [[ "$WRITE" -eq 1 ]]; then
  echo "$json_out" >"$BASELINE"
  echo "Wrote baseline → $BASELINE"
  exit 0
fi

if [[ "$MODE" == "report" ]]; then
  exit 0
fi

if [[ ! -f "$BASELINE" ]]; then
  echo "WARN  no baseline at $BASELINE — write with --write-baseline" >&2
  echo "$json_out" >"$BASELINE"
  echo "Wrote initial baseline → $BASELINE"
  exit 0
fi

# Compare: fail if skills_bytes, skills_lines, mdc_count, or always_on_window grow
python3 - <<PY
import json, sys
cur = json.loads('''$json_out''')
base = json.load(open("$BASELINE"))
fail = 0
# Ceiling ratchet: current must be <= baseline for these keys
keys = ["skills_bytes", "skills_lines", "mdc_count", "always_on_window_lines"]
for k in keys:
    c, b = cur.get(k, 0), base.get(k, 0)
    status = "OK" if c <= b else "FAIL"
    print(f"{status}  {k}: current={c} ceiling={b}")
    if c > b:
        fail += 1
# Report-only (not forced until later phases)
for k in ["duplicate_definition_hits", "orphan_ref_hits"]:
    c, b = cur.get(k, 0), base.get(k, 0)
    print(f"REPORT  {k}: current={c} baseline={b}")
sys.exit(1 if fail else 0)
PY
