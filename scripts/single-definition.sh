#!/usr/bin/env bash
# Single-definition gate: normative restatements of owned concepts outside
# the contract layer / declared owners. Pointers (真源/见 X) are OK.
#
# Contract-layer files under skills/vibe-coding/references/ may cross-link
# vocabulary; rail SKILL.md and non-owner references must not redefine.
#
# Usage:
#   bash scripts/single-definition.sh [--count|--strict]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE=report
for arg in "$@"; do
  case "$arg" in
    --count) MODE=count ;;
    --strict) MODE=strict ;;
  esac
done

# concept|extra_owners (comma-separated)|patterns
map_file=$(mktemp)
cat >"$map_file" <<'EOF'
write_auth||写码授权|\(a\)|\(b\)|\(c\)
construction|skills/dispatch-codex/SKILL.md|施工通道
human_gates||方案闸|验收闸|Deploy P4
states||acceptance-passed|awaiting-human-acceptance|close-spec
rails||Oracle 冻结|oracle-freeze
dispatch_unit|skills/dispatch-codex/SKILL.md|派发单元
material_polish|skills/vibe-coding/references/design-standards/change-control.md|\bmaterial\b
project_kind|templates/.cursor/rules/sdd-vibe-entry.mdc,skills/vibe-coding/references/project-kind.md|project\.kind
evidence_kind|skills/vibe-coding/references/evidence-contract.md|Evidence Kind|Deliver Gate
verification_loop|skills/vibe-coding/references/verification-loop.md|maker ≠ grader|verify-deliver
EOF

NORM='禁止|必须|须|不得|硬门'
POINTER='真源|见 \[|见 `|/gates\.md|/states\.md|/rails\.md|workflow-contract|详见|见 Skill|见 skill|见下方|见上方|见 \[`'

hits=0
details=$(mktemp)

is_contract_layer() {
  case "$1" in
    skills/vibe-coding/references/*|skills/vibe-coding/SKILL.md) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS='|' read -r concept extra_owners patterns; do
  [[ -z "$concept" || "$concept" =~ ^# ]] && continue
  IFS='|' read -ra toks <<<"$patterns"
  concept_re=$(IFS='|'; echo "${toks[*]}")
  owners=()
  IFS=',' read -ra eos <<<"$extra_owners"
  for o in "${eos[@]}"; do
    [[ -n "$o" ]] && owners+=("$o")
  done

  while IFS= read -r match; do
    file=${match%%:*}
    skip=0
    is_contract_layer "$file" && skip=1
    for o in "${owners[@]}"; do
      [[ "$file" == "$o" || "$file" == "./$o" ]] && skip=1 && break
    done
    [[ "$file" == *"/fixtures/"* || "$file" == *"/_archive/"* ]] && skip=1
    [[ $skip -eq 1 ]] && continue
    line=${match#*:}
    echo "$line" | grep -Eq "$NORM" || continue
    echo "$line" | grep -Eq "$POINTER" && continue
    echo "$concept|$file|$line" >>"$details"
    hits=$((hits + 1))
  done < <(grep -RnE "$concept_re" skills templates/.cursor --include='*.md' --include='*.mdc' 2>/dev/null || true)
done <"$map_file"

rm -f "$map_file"

if [[ "$MODE" == "count" ]]; then
  echo "$hits"
  rm -f "$details"
  exit 0
fi

echo "== single-definition hits=$hits =="
if [[ -s "$details" ]]; then
  cut -d'|' -f1 "$details" | sort | uniq -c | sort -rn
  echo "--- sample (≤30) ---"
  head -30 "$details" | while IFS='|' read -r c f l; do
    printf '  [%s] %s: %s\n' "$c" "$f" "$(echo "$l" | head -c 120)"
  done
fi
rm -f "$details"

if [[ "$MODE" == "strict" ]]; then
  [[ "$hits" -eq 0 ]]
else
  exit 0
fi
