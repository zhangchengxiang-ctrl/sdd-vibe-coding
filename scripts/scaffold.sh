#!/usr/bin/env bash
# Explicitly initialize a host repository with Codex SDD delivery memory.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$PLUGIN_ROOT/templates"
TARGET_INPUT="${1:-.}"

if [[ ! -d "$TARGET_INPUT" ]]; then
  echo "ERROR: target directory does not exist: $TARGET_INPUT" >&2
  exit 1
fi

TARGET="$(cd "$TARGET_INPUT" && pwd)"
echo "scaffold: target=$TARGET"

if [[ ! -f "$TARGET/AGENTS.md" ]]; then
  cp "$TEMPLATES/AGENTS.md" "$TARGET/AGENTS.md"
  echo "  + AGENTS.md"
fi

mkdir -p "$TARGET/docs"
while IFS= read -r -d '' file; do
  rel="${file#"$TEMPLATES/docs/"}"
  dest="$TARGET/docs/$rel"
  if [[ ! -e "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    echo "  + docs/$rel"
  fi
done < <(find "$TEMPLATES/docs" -type f -print0)

mkdir -p "$TARGET/scripts"
for checker in check-docs.sh check-docs.py; do
  if [[ ! -e "$TARGET/scripts/$checker" ]]; then
    cp "$PLUGIN_ROOT/scripts/$checker" "$TARGET/scripts/$checker"
    chmod +x "$TARGET/scripts/$checker"
    echo "  + scripts/$checker"
  fi
done

if [[ ! -f "$TARGET/docs/.sdd-scaffold" ]]; then
  printf 'sdd-superpowers-scaffold %s\n' "$(date -Iseconds)" > "$TARGET/docs/.sdd-scaffold"
  echo "  + docs/.sdd-scaffold"
fi
echo "scaffold: done"
