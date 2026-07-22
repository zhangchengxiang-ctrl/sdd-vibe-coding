#!/usr/bin/env bash
# install-local.sh — install SDD Superpowers for Cursor / Claude Code / Codex
# Usage:
#   bash scripts/install-local.sh              # all available harnesses
#   bash scripts/install-local.sh cursor
#   bash scripts/install-local.sh claude
#   bash scripts/install-local.sh codex
#   INSTALL_USER_HOOKS=0 bash scripts/install-local.sh cursor
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-all}"
INSTALL_USER_HOOKS="${INSTALL_USER_HOOKS:-1}"
VER="$(python3 -c "import json; print(json.load(open('$SRC/.claude-plugin/plugin.json'))['version'])")"

install_cursor() {
  local DST="${HOME}/.cursor/plugins/local/sdd-superpowers"
  mkdir -p "$(dirname "$DST")"
  if [[ -L "$DST" ]]; then rm "$DST"; fi
  mkdir -p "$DST"
  rsync -a --delete --exclude '.git' "$SRC/" "$DST/"
  echo "OK Cursor: $DST (v$VER)"

  if [[ "$INSTALL_USER_HOOKS" == "1" ]]; then
    local HOOKS_USER="${HOME}/.cursor/hooks.json"
    if [[ -f "$HOOKS_USER" ]] && ! grep -q 'sdd-superpowers' "$HOOKS_USER" 2>/dev/null; then
      cp "$HOOKS_USER" "${HOOKS_USER}.bak.$(date +%s)"
      echo "  backed up existing ~/.cursor/hooks.json"
    fi
    cat > "$HOOKS_USER" <<EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "node ${DST}/scripts/hooks/session-start.mjs" }
    ],
    "beforeSubmitPrompt": [
      { "command": "node ${DST}/scripts/hooks/before-submit-prompt.mjs" }
    ],
    "preToolUse": [
      {
        "command": "node ${DST}/scripts/hooks/pre-tool-use.mjs",
        "matcher": "Write|Delete|StrReplace|EditNotebook|Shell"
      }
    ]
  }
}
EOF
    echo "OK Cursor user hooks (fail-open unless workspace has .cursor/sdd-enabled)"
  fi
}

install_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "SKIP Claude: claude CLI not found"
    return 0
  fi
  # Register local marketplace (plugin root = repo; marketplace lives in .claude-plugin/)
  claude plugin marketplace add "$SRC/.claude-plugin/marketplace.json" 2>/dev/null || \
    claude plugin marketplace add "$SRC" 2>/dev/null || true
  claude plugin install "sdd-superpowers@sdd-superpowers-marketplace" 2>/dev/null || \
    claude plugin install sdd-superpowers 2>/dev/null || true

  # Dev symlink into cache so edits take effect without reinstall (best-effort)
  local CACHE_ROOT="${HOME}/.claude/plugins/cache"
  mkdir -p "$CACHE_ROOT"
  # Prefer known marketplace folder patterns; fall back to listing
  local LINK_DST=""
  for cand in \
    "$CACHE_ROOT/sdd-superpowers-marketplace/sdd-superpowers/$VER" \
    "$CACHE_ROOT/sdd-superpowers-marketplace/sdd-superpowers" \
    "$CACHE_ROOT/sdd-superpowers/$VER"
  do
    if [[ -e "$cand" || -L "$cand" ]]; then
      LINK_DST="$cand"
      break
    fi
  done
  if [[ -z "$LINK_DST" ]]; then
    LINK_DST="$CACHE_ROOT/sdd-superpowers-marketplace/sdd-superpowers/$VER"
    mkdir -p "$(dirname "$LINK_DST")"
  fi
  rm -rf "$LINK_DST"
  ln -s "$SRC" "$LINK_DST"
  echo "OK Claude Code: plugin install attempted; cache link → $LINK_DST"
  echo "  Next: /reload-plugins 或重启 Claude Code；/plugin 确认 sdd-superpowers"
}

install_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "SKIP Codex: codex CLI not found"
    return 0
  fi
  codex plugin marketplace remove sdd-superpowers-local 2>/dev/null || true
  codex plugin marketplace add "$SRC" 2>/dev/null || true
  codex plugin add "sdd-superpowers@sdd-superpowers-local" 2>/dev/null || \
    codex plugin add sdd-superpowers --marketplace sdd-superpowers-local 2>/dev/null || true
  echo "OK Codex: marketplace registered at $SRC"
  echo "  Next: Codex Plugins → SDD Superpowers；或 codex plugin add sdd-superpowers@sdd-superpowers-local"
}

case "$TARGET" in
  all)
    install_cursor
    install_claude
    install_codex
    ;;
  cursor) install_cursor ;;
  claude) install_claude ;;
  codex) install_codex ;;
  *)
    echo "Usage: $0 [all|cursor|claude|codex]" >&2
    exit 2
    ;;
esac

echo "done (v$VER)"
