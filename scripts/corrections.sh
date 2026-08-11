#!/usr/bin/env bash
# Local transcript correction scanner — buckets to M1/M2/M3.
# Pure local; no network; prints counts only.
# Usage: bash scripts/corrections.sh [days=14]
set -euo pipefail

DAYS="${1:-14}"
PASS=0

# Cursor + Claude transcript roots
CURSORS=(
  "$HOME/.cursor/projects"
)
CLAUDES=(
  "$HOME/.claude/projects"
)

# Plugin load signals
LOAD_RE='vibe-coding|workflow-contract|check_spec|codex-dispatch|sdd-vibe|wish-orchestrate|dispatch-codex'

# Correction lexicon → mechanism buckets
# M1: truth-source / duplication / blame / format hijack / entry pollution
# M2: add-rules / never-delete / patch-stack / slogan
# M3: form-as-quality / fake pass / checklist / residual / evidence theater
M1_RE='推卸|甩锅|入口太|什么提示词都能|格式|不是.*Vibe|词表.*打架|关版.*归档|project\.kind|默认.*coding'
M2_RE='叠补丁|打补丁|又写.*规则|停写|去掉.*规则|从来没有.*删除|垃圾规则|干净的重构'
M3_RE='骗人|作弊|敷衍|轻易就通过|形式|齐套|Checklist|checklist|验收.*假|假冒烟|评分不变|说优化完'

echo "== corrections (last ${DAYS}d) =="

# Collect candidate jsonl files with recent mtime containing load signal
tmp=$(mktemp)
find_jsonl() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  find "$root" -name '*.jsonl' -mtime -"$DAYS" -type f 2>/dev/null || true
}

: >"$tmp.files"
for r in "${CURSORS[@]}" "${CLAUDES[@]}"; do
  find_jsonl "$r" >>"$tmp.files"
done

loaded=0
m1=0
m2=0
m3=0
samples_m1=$(mktemp)
samples_m2=$(mktemp)
samples_m3=$(mktemp)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # cheap load-signal filter
  if ! grep -qE "$LOAD_RE" "$f" 2>/dev/null; then
    continue
  fi
  loaded=$((loaded + 1))
  # Extract user_query-ish lines (Cursor / Claude formats vary); scan whole file for lexicon
  if grep -qE "$M1_RE" "$f" 2>/dev/null; then
    m1=$((m1 + 1))
    if [[ $(wc -l <"$samples_m1") -lt 5 ]]; then
      grep -oE '.{0,40}('"$M1_RE"').{0,40}' "$f" 2>/dev/null | head -1 >>"$samples_m1" || true
    fi
  fi
  if grep -qE "$M2_RE" "$f" 2>/dev/null; then
    m2=$((m2 + 1))
    if [[ $(wc -l <"$samples_m2") -lt 5 ]]; then
      grep -oE '.{0,40}('"$M2_RE"').{0,40}' "$f" 2>/dev/null | head -1 >>"$samples_m2" || true
    fi
  fi
  if grep -qE "$M3_RE" "$f" 2>/dev/null; then
    m3=$((m3 + 1))
    if [[ $(wc -l <"$samples_m3") -lt 5 ]]; then
      grep -oE '.{0,40}('"$M3_RE"').{0,40}' "$f" 2>/dev/null | head -1 >>"$samples_m3" || true
    fi
  fi
done <"$tmp.files"

echo "sessions_with_plugin_load: $loaded"
echo "M1_truth_source_dup_blame: $m1"
echo "M2_add_rules_never_delete: $m2"
echo "M3_form_as_quality_fake_pass: $m3"
echo
echo "--- samples M1 ---"
head -5 "$samples_m1" 2>/dev/null || true
echo "--- samples M2 ---"
head -5 "$samples_m2" 2>/dev/null || true
echo "--- samples M3 ---"
head -5 "$samples_m3" 2>/dev/null || true

rm -f "$tmp.files" "$samples_m1" "$samples_m2" "$samples_m3"
echo "--- corrections done (local only; exit 0) ---"
exit 0
