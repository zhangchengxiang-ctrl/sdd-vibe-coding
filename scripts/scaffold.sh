#!/usr/bin/env bash
# Initialize a host repository with AGENTS.md + SDD delivery memory under a docs root.
# Does not copy harness dirs, rules, hooks, or check-docs.
#
# Usage:
#   bash scripts/scaffold.sh [TARGET] [options]
# Env (optional): PROFILE=… DRY_RUN=1 ALLOW_PARTIAL=1 SDD_ROOT=docs
#
# Profiles:
#   detect   — empty SDD root → full; else minimal; hard reserved-path conflict → exit 2
#   minimal  — brownfield default (product slots + specs/_template + reference)
#   full     — entire templates/docs tree
#
# SDD_ROOT (default docs): relative path where product/specs/reference live.
#   Example: --root=docs/sdd when host already owns docs/product semantics.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$PLUGIN_ROOT/templates"

PROFILE="${PROFILE:-detect}"
DRY_RUN="${DRY_RUN:-0}"
ALLOW_PARTIAL="${ALLOW_PARTIAL:-0}"
SDD_ROOT="${SDD_ROOT:-docs}"
TARGET_INPUT="."

usage() {
  cat <<'EOF'
Usage: bash scripts/scaffold.sh [TARGET] [options]

Options:
  --profile detect|minimal|full   Default: detect (or $PROFILE)
  --root PATH                     SDD docs root, relative (default: docs; or $SDD_ROOT)
  --dry-run                       Probe only; do not write (or DRY_RUN=1)
  --allow-partial                 Write non-blocked paths even if BLOCK exists (or ALLOW_PARTIAL=1)
  -h, --help                      Show this help

Exit codes:
  0  ok (or dry-run with no BLOCK)
  1  usage / missing templates / target
  2  hard reserved-path conflict (refused unless --allow-partial)
EOF
}

normalize_sdd_root() {
  local r="$1"
  r="${r#./}"
  r="${r%/}"
  if [[ -z "$r" || "$r" == "/" ]]; then
    echo "ERROR: --root must be a non-empty relative path (default: docs)" >&2
    return 1
  fi
  if [[ "$r" == /* ]]; then
    echo "ERROR: --root must be relative to the host repo (got absolute: $r)" >&2
    return 1
  fi
  if [[ "$r" == *".."* ]]; then
    echo "ERROR: --root must not contain '..' (got: $r)" >&2
    return 1
  fi
  printf '%s\n' "$r"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || { echo "ERROR: --profile needs a value" >&2; exit 1; }
      PROFILE="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#--profile=}"
      shift
      ;;
    --root)
      [[ $# -ge 2 ]] || { echo "ERROR: --root needs a value" >&2; exit 1; }
      SDD_ROOT="$2"
      shift 2
      ;;
    --root=*)
      SDD_ROOT="${1#--root=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --allow-partial)
      ALLOW_PARTIAL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      TARGET_INPUT="$1"
      shift
      ;;
  esac
done

case "$PROFILE" in
  detect|minimal|full) ;;
  *)
    echo "ERROR: invalid profile '$PROFILE' (want detect|minimal|full)" >&2
    exit 1
    ;;
esac

SDD_ROOT="$(normalize_sdd_root "$SDD_ROOT")" || exit 1

if [[ ! -d "$TARGET_INPUT" ]]; then
  echo "ERROR: target directory does not exist: $TARGET_INPUT" >&2
  exit 1
fi
if [[ ! -d "$TEMPLATES/docs" ]]; then
  echo "ERROR: templates not found at $TEMPLATES/docs" >&2
  exit 1
fi

TARGET="$(cd "$TARGET_INPUT" && pwd)"

# --- minimal profile relative paths under SDD root ---
is_minimal_rel() {
  local rel="$1"
  case "$rel" in
    README.md) return 0 ;;
    product/README.md|product/demand-pool.md|product/gap-register.md) return 0 ;;
    product/modules/.gitkeep) return 0 ;;
    reference/handoff.md|reference/claims.md) return 0 ;;
    specs/_template/*) return 0 ;;
    *) return 1 ;;
  esac
}

product_looks_sdd() {
  local d="$1/$SDD_ROOT/product"
  [[ -f "$d/demand-pool.md" || -f "$d/gap-register.md" || -d "$d/modules" || -d "$d/foundation" ]]
}

specs_look_sdd() {
  local d="$1/$SDD_ROOT/specs"
  [[ -d "$d/_template" ]] && return 0
  local hit
  hit="$(find "$d" -mindepth 2 -maxdepth 2 -name 'contract.md' -print -quit 2>/dev/null || true)"
  [[ -n "$hit" ]]
}

sdd_root_emptyish() {
  local d="$1/$SDD_ROOT"
  [[ ! -d "$d" ]] && return 0
  [[ -z "$(find "$d" -type f -print -quit 2>/dev/null)" ]]
}

# Collect BLOCK reasons into array BLOCK_REASONS (paths relative to SDD_ROOT)
BLOCK_REASONS=()
probe_blocks() {
  BLOCK_REASONS=()
  local root="$1"
  local product="$root/$SDD_ROOT/product"
  local specs="$root/$SDD_ROOT/specs"
  local reference="$root/$SDD_ROOT/reference"

  if [[ -e "$product" && ! -d "$product" ]]; then
    BLOCK_REASONS+=("$SDD_ROOT/product exists but is not a directory")
  elif [[ -d "$product" ]] && ! product_looks_sdd "$root"; then
    if [[ -n "$(find "$product" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      BLOCK_REASONS+=("$SDD_ROOT/product/ looks non-SDD (no demand-pool/gap-register/modules/foundation); move aside, or use --root=docs/sdd")
    fi
  fi

  if [[ -e "$specs" && ! -d "$specs" ]]; then
    BLOCK_REASONS+=("$SDD_ROOT/specs exists but is not a directory")
  elif [[ -d "$specs" ]] && ! specs_look_sdd "$root"; then
    if [[ -n "$(find "$specs" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
      BLOCK_REASONS+=("$SDD_ROOT/specs/ looks non-SDD (no _template/ and no */contract.md); move aside, or use --root=docs/sdd")
    fi
  fi

  if [[ -e "$reference" && ! -d "$reference" ]]; then
    BLOCK_REASONS+=("$SDD_ROOT/reference exists but is not a directory")
  fi
}

resolve_profile() {
  local root="$1"
  local want="$2"
  if [[ "$want" != "detect" ]]; then
    echo "$want"
    return
  fi
  if sdd_root_emptyish "$root"; then
    echo "full"
  else
    echo "minimal"
  fi
}

stamp_agents_sdd_root() {
  local agents="$1"
  local root_val="$2"
  local cur=""
  if grep -qE '^[[:space:]]*-[[:space:]]*SDD docs root:' "$agents"; then
    cur="$(sed -nE 's/^[[:space:]]*-[[:space:]]*SDD docs root:[[:space:]]*//p' "$agents" | head -1 | tr -d '\r')"
    if [[ "$cur" == "$root_val" ]]; then
      return 0
    fi
    local tmp
    tmp="$(mktemp)"
    sed -E "s|^([[:space:]]*-[[:space:]]*SDD docs root:).*|\1 ${root_val}|" "$agents" >"$tmp"
    mv "$tmp" "$agents"
    return 0
  fi
  if grep -qE '^## SDD[[:space:]]*$' "$agents"; then
    local tmp
    tmp="$(mktemp)"
    awk -v root="$root_val" '
      BEGIN { done=0 }
      /^## SDD[[:space:]]*$/ { print; print "- SDD docs root: " root; done=1; next }
      { print }
      END { if (!done) print "- SDD docs root: " root }
    ' "$agents" >"$tmp"
    mv "$tmp" "$agents"
  else
    printf '\n## SDD\n\n- SDD docs root: %s\n' "$root_val" >>"$agents"
  fi
}

EFFECTIVE_PROFILE="$(resolve_profile "$TARGET" "$PROFILE")"
probe_blocks "$TARGET"

echo "scaffold: target=$TARGET"
echo "scaffold: sdd_root=$SDD_ROOT profile=$PROFILE → effective=$EFFECTIVE_PROFILE dry_run=$DRY_RUN allow_partial=$ALLOW_PARTIAL"

echo "scaffold probe:"
HAS_BLOCK=0
if ((${#BLOCK_REASONS[@]})); then
  HAS_BLOCK=1
  for reason in "${BLOCK_REASONS[@]}"; do
    echo "  BLOCK $reason"
  done
fi

plan_copy_docs() {
  local rel="$1"
  if [[ "$EFFECTIVE_PROFILE" == "minimal" ]] && ! is_minimal_rel "$rel"; then
    return 1
  fi
  return 0
}

WOULD_WRITE=0
WOULD_SKIP=0
WOULD_OMIT=0
while IFS= read -r -d '' file; do
  rel="${file#"$TEMPLATES/docs/"}"
  dest="$TARGET/$SDD_ROOT/$rel"
  if ! plan_copy_docs "$rel"; then
    WOULD_OMIT=$((WOULD_OMIT + 1))
    continue
  fi
  if [[ -e "$dest" ]]; then
    echo "  SKIP $SDD_ROOT/$rel (exists)"
    WOULD_SKIP=$((WOULD_SKIP + 1))
  else
    echo "  OK   + would write $SDD_ROOT/$rel"
    WOULD_WRITE=$((WOULD_WRITE + 1))
  fi
done < <(find "$TEMPLATES/docs" -type f -print0 | sort -z)

for name in AGENTS.md CLAUDE.md; do
  if [[ -e "$TARGET/$name" ]]; then
    echo "  SKIP $name (exists)"
    WOULD_SKIP=$((WOULD_SKIP + 1))
  else
    echo "  OK   + would write $name"
    WOULD_WRITE=$((WOULD_WRITE + 1))
  fi
done

# Optional host architecture slots (full only; always under docs/architecture, not SDD_ROOT)
if [[ "$EFFECTIVE_PROFILE" == "full" && -d "$TEMPLATES/architecture" ]]; then
  while IFS= read -r -d '' file; do
    rel="${file#"$TEMPLATES/architecture/"}"
    dest="$TARGET/docs/architecture/$rel"
    if [[ -e "$dest" ]]; then
      echo "  SKIP docs/architecture/$rel (exists)"
      WOULD_SKIP=$((WOULD_SKIP + 1))
    else
      echo "  OK   + would write docs/architecture/$rel"
      WOULD_WRITE=$((WOULD_WRITE + 1))
    fi
  done < <(find "$TEMPLATES/architecture" -type f -print0 | sort -z)
fi

if [[ "$SDD_ROOT" != "docs" ]]; then
  echo "  NOTE SDD root is '$SDD_ROOT' — skills must read AGENTS.md «SDD docs root» and map docs/product → $SDD_ROOT/product"
fi
if [[ -e "$TARGET/$SDD_ROOT/README.md" ]]; then
  echo "  NOTE $SDD_ROOT/README.md exists — append an SDD map section if it is a host index"
fi
if [[ "$HAS_BLOCK" -eq 1 && "$SDD_ROOT" == "docs" ]]; then
  echo "  HINT hard conflict under docs/ — try: --root=docs/sdd  (keeps host docs/, isolates SDD)"
fi

echo "scaffold probe summary: write=$WOULD_WRITE skip=$WOULD_SKIP omit_profile=$WOULD_OMIT blocks=$HAS_BLOCK"

if [[ "$HAS_BLOCK" -eq 1 && "$ALLOW_PARTIAL" != "1" ]]; then
  echo "scaffold: refused (hard conflict). Fix BLOCK paths, use --root=docs/sdd, or --allow-partial." >&2
  echo "scaffold: suggested: mv conflicting trees under docs/_host/ then re-run; or isolate with --root=docs/sdd." >&2
  exit 2
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "scaffold: dry-run done (no writes)"
  exit 0
fi

# --- writes ---
AGENTS_NEW=0
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
  cp "$TEMPLATES/AGENTS.md" "$TARGET/AGENTS.md"
  echo "  + AGENTS.md"
  AGENTS_NEW=1
fi
# Always ensure AGENTS has the correct SDD docs root bullet.
before_agents_hash="$(cksum "$TARGET/AGENTS.md" | awk '{print $1}')"
stamp_agents_sdd_root "$TARGET/AGENTS.md" "$SDD_ROOT"
after_agents_hash="$(cksum "$TARGET/AGENTS.md" | awk '{print $1}')"
if [[ "$AGENTS_NEW" -eq 0 && "$before_agents_hash" != "$after_agents_hash" ]]; then
  echo "  ~ AGENTS.md SDD docs root → $SDD_ROOT"
fi

if [[ ! -f "$TARGET/CLAUDE.md" ]]; then
  printf '%s\n' '@AGENTS.md' > "$TARGET/CLAUDE.md"
  echo "  + CLAUDE.md"
fi

mkdir -p "$TARGET/$SDD_ROOT"
while IFS= read -r -d '' file; do
  rel="${file#"$TEMPLATES/docs/"}"
  dest="$TARGET/$SDD_ROOT/$rel"
  if ! plan_copy_docs "$rel"; then
    continue
  fi
  if [[ ! -e "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    echo "  + $SDD_ROOT/$rel"
  fi
done < <(find "$TEMPLATES/docs" -type f -print0 | sort -z)

if [[ "$EFFECTIVE_PROFILE" == "full" && -d "$TEMPLATES/architecture" ]]; then
  while IFS= read -r -d '' file; do
    rel="${file#"$TEMPLATES/architecture/"}"
    dest="$TARGET/docs/architecture/$rel"
    if [[ ! -e "$dest" ]]; then
      mkdir -p "$(dirname "$dest")"
      cp "$file" "$dest"
      echo "  + docs/architecture/$rel"
    fi
  done < <(find "$TEMPLATES/architecture" -type f -print0 | sort -z)
fi

echo "scaffold: done (profile=$EFFECTIVE_PROFILE sdd_root=$SDD_ROOT)"
