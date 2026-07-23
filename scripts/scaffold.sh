#!/usr/bin/env bash
# scaffold.sh — 空仓生成 AGENTS.md + docs 骨架 + 项目硬闸 + check-docs
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$PLUGIN_ROOT/templates"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

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
  dest="$TARGET/docs/$rel"
  if [[ ! -e "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    echo "  + docs/$rel"
  fi
done < <(find "$TEMPLATES/docs" -type f -print0)

# Always refresh gate rules + hooks from plugin (Cursor + Claude Code)
mkdir -p "$TARGET/.cursor/rules" "$TARGET/.claude/rules"
for f in "$PLUGIN_ROOT"/rules/*.mdc; do
  base="$(basename "$f")"
  cp "$f" "$TARGET/.cursor/rules/$base"
  echo "  + .cursor/rules/$base"
  # Claude Code prefers .claude/rules/*.md
  md="${base%.mdc}.md"
  # Strip Cursor-only alwaysApply frontmatter keys; keep body
  python3 - "$f" "$TARGET/.claude/rules/$md" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding='utf-8').read()
if text.startswith('---'):
    parts = text.split('---', 2)
    if len(parts) >= 3:
        fm, body = parts[1], parts[2]
        # Drop alwaysApply / globs Cursor keys; keep description if any
        keep = []
        for line in fm.splitlines():
            if re.match(r'^\s*(alwaysApply|globs)\s*:', line):
                continue
            keep.append(line)
        fm2 = '\n'.join(keep).strip()
        text = f"---\n{fm2}\n---{body}" if fm2 else body.lstrip('\n')
open(dst, 'w', encoding='utf-8').write(text)
PY
  echo "  + .claude/rules/$md"
done

mkdir -p "$TARGET/.cursor/hooks"
# Cursor host only needs shared lib + Cursor entrypoints (not Claude --harness paths)
for hook in shared.mjs session.mjs prompt.mjs tool.mjs; do
  cp "$PLUGIN_ROOT/scripts/hooks/$hook" "$TARGET/.cursor/hooks/$hook"
done
cat > "$TARGET/.cursor/hooks.json" <<'EOF'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "node .cursor/hooks/session.mjs" }
    ],
    "beforeSubmitPrompt": [
      { "command": "node .cursor/hooks/prompt.mjs" }
    ],
    "preToolUse": [
      {
        "command": "node .cursor/hooks/tool.mjs",
        "matcher": "Write|Delete|StrReplace|EditNotebook|Shell"
      }
    ]
  }
}
EOF
echo "  + .cursor/hooks.json + hooks"
touch "$TARGET/.cursor/sdd-enabled"
touch "$TARGET/.claude/sdd-enabled"
echo "  + .cursor/sdd-enabled + .claude/sdd-enabled"

# Project-level Claude hooks (optional; plugin hooks preferred when installed)
mkdir -p "$TARGET/.claude"
if [[ ! -f "$TARGET/.claude/settings.json" ]]; then
  cat > "$TARGET/.claude/settings.json" <<'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {}
}
EOF
  echo "  + .claude/settings.json"
fi

mkdir -p "$TARGET/scripts"
cp "$PLUGIN_ROOT/scripts/check-docs.sh" "$TARGET/scripts/check-docs.sh"
chmod +x "$TARGET/scripts/check-docs.sh"
echo "  + scripts/check-docs.sh"

echo "sdd-superpowers-scaffold $(date -Iseconds)" >> "$TARGET/docs/.sdd-scaffold"
echo "scaffold: done"
