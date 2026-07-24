#!/usr/bin/env bash
# Initialize a host repository with AGENTS.md + docs/ delivery memory.
# Does not copy harness dirs, rules, hooks, or check-docs.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$PLUGIN_ROOT/templates"
TARGET_INPUT="${1:-.}"

if [[ ! -d "$TARGET_INPUT" ]]; then
  echo "ERROR: target directory does not exist: $TARGET_INPUT" >&2
  exit 1
fi
if [[ ! -d "$TEMPLATES" ]]; then
  echo "ERROR: templates not found at $TEMPLATES" >&2
  exit 1
fi

TARGET="$(cd "$TARGET_INPUT" && pwd)"
echo "scaffold: target=$TARGET"

if [[ ! -f "$TARGET/AGENTS.md" ]]; then
  cp "$TEMPLATES/AGENTS.md" "$TARGET/AGENTS.md"
  echo "  + AGENTS.md"
fi

if [[ ! -f "$TARGET/CLAUDE.md" ]]; then
  printf '%s\n' '@AGENTS.md' > "$TARGET/CLAUDE.md"
  echo "  + CLAUDE.md"
fi

mkdir -p "$TARGET/docs"
while IFS= read -r -d '' file; do
  rel="${file#"$TEMPLATES/docs/"}"
  case "$rel" in
    specs/_template/optional/problem-map.md|\
    specs/_template/optional/research.md|\
    specs/_template/optional/commit-checklist.md|\
    specs/_template/optional/scope.md|\
    specs/_template/optional/product-design.md|\
    specs/_template/optional/experience-design.md)
      continue
      ;;
  esac
  dest="$TARGET/docs/$rel"
  if [[ ! -e "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    echo "  + docs/$rel"
  fi
done < <(find "$TEMPLATES/docs" -type f -print0)

echo "scaffold: done"
