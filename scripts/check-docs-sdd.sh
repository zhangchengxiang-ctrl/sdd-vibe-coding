#!/usr/bin/env bash
# Portable SDD docs integrity check. Run from host repo root:
#   bash scripts/check-docs-sdd.sh
# Or: bash /path/to/sdd-superpowers/scripts/check-docs-sdd.sh /path/to/host
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -n "${1:-}" && -f "$1/AGENTS.md" ]]; then
  ROOT="$(cd "$1" && pwd)"
elif [[ -f "$PWD/AGENTS.md" ]]; then
  ROOT="$PWD"
elif [[ -f "$SCRIPT_DIR/../AGENTS.md" ]]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  echo "ERROR: run from host repo root (AGENTS.md) or pass host path" >&2
  exit 1
fi
cd "$ROOT"

WIP_CAP="${WIP_CAP:-8}"
errors=0
warn=0
fail() { echo "ERROR: $*" >&2; errors=$((errors + 1)); }
warn_msg() { echo "WARN: $*" >&2; warn=$((warn + 1)); }
ok() { echo "OK: $*"; }

DOCS_README=""
for c in docs/README.md docs/README.zh-CN.md; do
  [[ -f "$c" ]] && DOCS_README="$c" && break
done

echo "== skeleton ($ROOT) =="
for f in AGENTS.md docs/reference/handoff.md docs/specs/_template/VERSION.md docs/product/README.md; do
  [[ -e "$f" ]] && ok "$f" || fail "missing $f"
done
[[ -n "$DOCS_README" ]] && ok "$DOCS_README" || fail "missing docs/README.md"
[[ -f docs/product/foundation/product-regression.md ]] && ok "product-regression" || warn_msg "missing product-regression"
[[ -f docs/product/regression/surfaces.json ]] && ok "surfaces.json" || warn_msg "missing surfaces.json"
[[ -f docs/product/demand-pool.md ]] && ok "demand-pool" || warn_msg "missing demand-pool"
[[ -f docs/planning/roadmap.md ]] && ok "roadmap" || warn_msg "missing roadmap"

for forbidden in .agents/skills .claude/skills .cursor/skills; do
  if [[ -e "$forbidden" ]]; then
    fail "remove repo $forbidden"
  else
    ok "no $forbidden"
  fi
done

if [[ -f CLAUDE.md ]]; then
  if [[ ! -L CLAUDE.md ]] && [[ "$(tr -d '[:space:]' < CLAUDE.md)" == "@AGENTS.md" ]]; then
    ok "CLAUDE.md stub"
  else
    warn_msg "CLAUDE.md should be '@AGENTS.md' stub"
  fi
fi

echo "== VERSION template =="
for marker in "Delivery Target" "Current Gate" "Requirements Lock"; do
  grep -q "$marker" docs/specs/_template/VERSION.md 2>/dev/null && ok "$marker" || fail "VERSION missing $marker"
done

if [[ -f docs/specs/_template/optional/scenario-spec.md ]]; then
  for marker in ORACLE EFFECTIVE_CHANNEL FAILURE_ROUTE; do
    grep -q "$marker" docs/specs/_template/optional/scenario-spec.md && ok "scenario $marker" || fail "scenario missing $marker"
  done
fi

echo "== handoff / WIP =="
grep -q '^## 活跃 Spec' docs/reference/handoff.md && ok "§活跃 Spec" || fail "handoff missing §活跃 Spec"
active_rows=$(awk '/^## 活跃 Spec/{flag=1;next}/^## /{flag=0}flag' docs/reference/handoff.md | grep -cE '^\| \[' || true)
[[ "$active_rows" -gt "$WIP_CAP" ]] && fail "活跃 Spec $active_rows > WIP_CAP=$WIP_CAP" || ok "rows=$active_rows (cap $WIP_CAP)"

while IFS= read -r sid; do
  [[ -z "$sid" ]] && continue
  root="docs/specs/$sid/scenario-spec.md"
  opt="docs/specs/$sid/optional/scenario-spec.md"
  if [[ -f "$opt" && ! -f "$root" ]]; then fail "$sid: scenario only in optional/"; fi
  if [[ -f "$opt" && -f "$root" ]]; then fail "$sid: scenario dual copy"; fi
done < <(awk '/^## 活跃 Spec/{flag=1;next}/^## /{flag=0}flag' docs/reference/handoff.md \
  | grep -oE 'v[0-9]{4}\.[0-9]{2}-[a-z0-9-]+' | sort -u || true)

SPEC_STATUS_ENUM='draft|in-progress|review|done|archived|cancelled'
extract_version_status() {
  local st
  st=$(grep -E '^\|\s*\*{0,2}状态\*{0,2}\s*\|' "$1" 2>/dev/null | head -1 | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\*\*//g')
  printf '%s' "$(printf '%s' "$st" | awk '{print $1}' | tr -d '`')"
}

for vf in docs/specs/v*/VERSION.md; do
  [[ -f "$vf" ]] || continue
  st=$(extract_version_status "$vf")
  sid=$(basename "$(dirname "$vf")")
  [[ -z "$st" ]] && fail "VERSION missing status: $sid" && continue
  printf '%s\n' "$st" | grep -qE "^($SPEC_STATUS_ENUM)$" || fail "bad status '$st' $sid"
  [[ "$st" == "done" || "$st" == "archived" || "$st" == "cancelled" ]] && fail "closed status in active tree: $sid"
  ok "VERSION $sid=$st"
done

while IFS= read -r line; do
  spec_id=$(printf '%s\n' "$line" | grep -oE 'v[0-9]{4}\.[0-9]{2}-[a-z0-9-]+' | head -1)
  [[ -n "$spec_id" ]] || continue
  handoff_st=$(printf '%s\n' "$line" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\*\*//g' | awk '{print $1}')
  vf="docs/specs/${spec_id}/VERSION.md"
  [[ -f "$vf" ]] || { fail "handoff $spec_id missing VERSION"; continue; }
  ver_st=$(extract_version_status "$vf")
  [[ "$handoff_st" == "$ver_st" ]] && ok "handoff↔VERSION $spec_id" || fail "handoff '$handoff_st' != VERSION '$ver_st' ($spec_id)"
done < <(awk '/^## 活跃 Spec/{flag=1;next}/^## /{flag=0}flag' docs/reference/handoff.md | grep -E '^\| \[' || true)

handoff_ids=$(awk '/^## 活跃 Spec/{flag=1;next}/^## /{flag=0}flag' docs/reference/handoff.md \
  | grep -oE 'v[0-9]{4}\.[0-9]{2}-[a-z0-9-]+' | sort -u || true)
for vf in docs/specs/v*/VERSION.md; do
  [[ -f "$vf" ]] || continue
  sid=$(basename "$(dirname "$vf")")
  if [[ -n "$handoff_ids" ]] && ! printf '%s\n' "$handoff_ids" | grep -qxF "$sid"; then
    fail "orphan active spec: $sid"
  fi
done

[[ -f docs/product/README.md ]] && grep -q '^## 状态枚举' docs/product/README.md && ok "product §状态枚举" || fail "product README missing §状态枚举"

if [[ -f docs/product/regression/surfaces.json ]]; then
  python3 - <<'PY'
import json, os, sys
d=json.load(open("docs/product/regression/surfaces.json"))
err=0
for s in d.get("surfaces",[]):
  if s.get("status")=="active" and s.get("map") and not os.path.isfile(s["map"]):
    print("ERROR: map missing", s["map"], file=sys.stderr); err=1
  elif s.get("status")=="active" and s.get("map"):
    print("OK: map", s["map"])
sys.exit(err)
PY
fi

echo "---"
echo "errors=$errors warnings=$warn WIP_CAP=$WIP_CAP"
[[ "$errors" -eq 0 ]]
