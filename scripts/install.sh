#!/usr/bin/env bash
# Install SDD Vibe Coding as a local skills plugin for Cursor / Claude Code / Codex.
# Protocol manifests are generated into a cache stage — never into the git tree.
#
# Usage:
#   bash scripts/install.sh              # all available harnesses
#   bash scripts/install.sh cursor
#   bash scripts/install.sh claude
#   bash scripts/install.sh codex
#   bash scripts/install.sh --dev …      # symlink skills/ → repo (edit without reinstall)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/sdd-vibe-coding/stage"
PLUGIN_NAME="sdd-vibe-coding"
MARKETPLACE_LOCAL="${PLUGIN_NAME}-local"
DEV=0
TARGET="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev) DEV=1; shift ;;
    all|cursor|claude|codex) TARGET="$1"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Usage: $0 [--dev] [all|cursor|claude|codex]" >&2
      exit 2
      ;;
  esac
done

version="$(
  python3 -c "import json; print(json.load(open('$ROOT/package.json', encoding='utf-8'))['version'])"
)"
description="$(
  python3 -c "import json; print(json.load(open('$ROOT/package.json', encoding='utf-8'))['description'])"
)"

stage_dir() {
  echo "$STAGE_ROOT/$1"
}

populate_stage() {
  local harness="$1"
  local stage
  stage="$(stage_dir "$harness")"
  rm -rf "$stage"
  mkdir -p "$stage/scripts"

  if [[ "$DEV" == "1" ]]; then
    ln -s "$ROOT/skills" "$stage/skills"
    ln -s "$ROOT/templates" "$stage/templates"
    [[ -d "$ROOT/assets" ]] && ln -s "$ROOT/assets" "$stage/assets"
  else
    mkdir -p "$stage/skills" "$stage/templates"
    rsync -a --delete "$ROOT/skills/" "$stage/skills/"
    rsync -a --delete "$ROOT/templates/" "$stage/templates/"
    if [[ -d "$ROOT/assets" ]]; then
      mkdir -p "$stage/assets"
      rsync -a --delete "$ROOT/assets/" "$stage/assets/"
    fi
  fi

  cp "$ROOT/scripts/scaffold.sh" "$stage/scripts/scaffold.sh"
  chmod +x "$stage/scripts/scaffold.sh"
  cp "$ROOT/package.json" "$stage/package.json"
  [[ -f "$ROOT/LICENSE" ]] && cp "$ROOT/LICENSE" "$stage/LICENSE"
  [[ -f "$ROOT/README.md" ]] && cp "$ROOT/README.md" "$stage/README.md"

  emit_manifest "$harness" "$stage"
  echo "stage: $stage (v$version)"
}

emit_manifest() {
  local harness="$1"
  local stage="$2"
  case "$harness" in
    cursor)
      mkdir -p "$stage/.cursor-plugin"
      python3 - "$stage/.cursor-plugin/plugin.json" "$PLUGIN_NAME" "$version" "$description" <<'PY'
import json, sys
path, name, version, description = sys.argv[1:5]
json.dump(
    {
        "name": name,
        "version": version,
        "description": description,
        "author": {"name": "SDD Vibe Coding"},
        "keywords": ["sdd", "spec-driven", "vibe-coding", "skills"],
        "skills": "./skills/",
    },
    open(path, "w", encoding="utf-8"),
    ensure_ascii=False,
    indent=2,
)
print(file=open(path, "a", encoding="utf-8"))
PY
      ;;
    claude)
      mkdir -p "$stage/.claude-plugin"
      python3 - "$stage" "$PLUGIN_NAME" "$version" "$description" <<'PY'
import json, sys
from pathlib import Path
stage, name, version, description = sys.argv[1:5]
stage = Path(stage)
plugin = {
    "name": name,
    "version": version,
    "description": description,
    "author": {"name": "SDD Vibe Coding"},
    "keywords": ["sdd", "spec-driven", "vibe-coding", "skills"],
    "skills": "./skills/",
}
(stage / ".claude-plugin" / "plugin.json").write_text(
    json.dumps(plugin, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
marketplace = {
    "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
    "name": f"{name}-marketplace",
    "description": f"{name} local marketplace",
    "owner": {"name": "SDD Vibe Coding"},
    "metadata": {"description": description, "version": version},
    "plugins": [
        {
            "name": name,
            "description": description,
            "version": version,
            "author": {"name": "SDD Vibe Coding"},
            "source": "./",
            "category": "productivity",
        }
    ],
}
(stage / ".claude-plugin" / "marketplace.json").write_text(
    json.dumps(marketplace, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY
      ;;
    codex)
      mkdir -p "$stage/.codex-plugin" "$stage/.agents/plugins"
      python3 - "$stage" "$PLUGIN_NAME" "$version" "$description" "$MARKETPLACE_LOCAL" <<'PY'
import json, sys
from pathlib import Path
stage, name, version, description, marketplace_name = sys.argv[1:6]
stage = Path(stage)
plugin = {
    "name": name,
    "version": version,
    "description": description,
    "author": {"name": "SDD Vibe Coding"},
    "license": "MIT",
    "keywords": ["sdd", "spec-driven", "vibe-coding", "skills"],
    "skills": "./skills/",
    "interface": {
        "displayName": "Vibe Coding",
        "shortDescription": "Spec-Driven Delivery skills for any repo.",
        "longDescription": description,
        "developerName": "SDD Vibe Coding",
        "category": "Productivity",
        "capabilities": ["Read", "Write", "Workflow"],
        "defaultPrompt": [
            "我有一个产品想法，请先帮我理解清楚，并告诉我只需要决定什么。",
            "产品方向已经确认，请用业务结果说明实施顺序、关键风险和下一步，先不要编码。",
            "请按真实用户旅程验收当前版本，先告诉我是否可以交付，再给出证据和限制。",
        ],
    },
}
(stage / ".codex-plugin" / "plugin.json").write_text(
    json.dumps(plugin, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
marketplace = {
    "name": marketplace_name,
    "interface": {"displayName": "Vibe Coding (local)"},
    "plugins": [
        {
            "name": name,
            "source": {"source": "local", "path": "./"},
            "policy": {
                "installation": "AVAILABLE",
                "authentication": "ON_INSTALL",
            },
            "category": "Productivity",
        }
    ],
}
(stage / ".agents" / "plugins" / "marketplace.json").write_text(
    json.dumps(marketplace, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY
      ;;
  esac
}

# Cursor `/skill-name` and filesystem discovery only scan ~/.cursor/skills (and
# project/.cursor/skills), NOT ~/.cursor/plugins/local/.../skills. Dual-link so
# slash commands and Agent Decides both see the same SDD skills.
link_cursor_user_skills() {
  local skill_src_root="$1"
  local user_skills="${HOME}/.cursor/skills"
  mkdir -p "$user_skills"
  local skill_md name dst abs
  shopt -s nullglob
  for skill_md in "$skill_src_root"/*/SKILL.md; do
    name="$(basename "$(dirname "$skill_md")")"
    dst="$user_skills/$name"
    abs="$(cd "$(dirname "$skill_md")" && pwd)"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      echo "  WARN: skip ~/.cursor/skills/$name (exists, not a symlink)" >&2
      continue
    fi
    ln -sfn "$abs" "$dst"
    echo "  linked ~/.cursor/skills/$name → $abs"
  done
  shopt -u nullglob
}

# Session hard gates: alwaysApply rules under templates/.cursor/rules → ~/.cursor/rules.
link_cursor_user_rules() {
  local rules_src="$1"
  local user_rules="${HOME}/.cursor/rules"
  local f name dst abs
  if [[ ! -d "$rules_src" ]]; then
    echo "  WARN: no rules dir at $rules_src" >&2
    return 0
  fi
  mkdir -p "$user_rules"
  shopt -s nullglob
  for f in "$rules_src"/*.mdc; do
    name="$(basename "$f")"
    dst="$user_rules/$name"
    abs="$(cd "$(dirname "$f")" && pwd)/$name"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      echo "  WARN: replace ~/.cursor/rules/$name (was a regular file) with plugin symlink" >&2
    fi
    ln -sfn "$abs" "$dst"
    echo "  linked ~/.cursor/rules/$name → $abs"
  done
  shopt -u nullglob

  # Migrate pre-plugin user rule: keep name, point readers at shipped sdd-codex-cli.
  local legacy="${user_rules}/codex-mcp.mdc"
  if [[ -e "$legacy" || -L "$legacy" ]]; then
    if [[ -L "$legacy" ]]; then
      # If someone already symlinked elsewhere, leave it.
      :
    else
      cat >"$legacy" <<'EOF'
---
description: Deprecated stub — Codex CLI hard gate is sdd-codex-cli.mdc (plugin install)
alwaysApply: true
---

# Deprecated: codex-mcp.mdc

Codex 派发硬门已迁到插件投影 **`sdd-codex-cli.mdc`**（`make install-cursor`）。  
本文件仅作兼容占位；以 `sdd-codex-cli.mdc` 为准。禁止 Codex MCP。
EOF
      echo "  migrated ~/.cursor/rules/codex-mcp.mdc → stub (see sdd-codex-cli.mdc)"
    fi
  fi
}

install_cursor() {
  if ! command -v rsync >/dev/null 2>&1; then
    echo "SKIP Cursor: rsync not found" >&2
    return 0
  fi
  populate_stage cursor
  local stage dst skill_src rules_src
  stage="$(stage_dir cursor)"
  dst="${HOME}/.cursor/plugins/local/${PLUGIN_NAME}"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  fi
  mkdir -p "$dst"
  rsync -a --delete \
    --exclude '.git' \
    "$stage/" "$dst/"
  # Prefer repo paths under --dev so skill edits are live for `/` discovery.
  if [[ "$DEV" == "1" ]]; then
    skill_src="$ROOT/skills"
    rules_src="$ROOT/templates/.cursor/rules"
  else
    skill_src="$dst/skills"
    rules_src="$dst/templates/.cursor/rules"
  fi
  link_cursor_user_skills "$skill_src"
  link_cursor_user_rules "$rules_src"
  echo "OK Cursor: $dst (v$version)"
  echo "  Next: Developer: Reload Window → Plugins 见 ${PLUGIN_NAME}；Agent 输入 /vibe-coding"
  echo "  Rules: ~/.cursor/rules/sdd-*.mdc（入口 / 写码闸 / Deploy P4 / Codex CLI）"
}

install_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "SKIP Claude: claude CLI not found"
    return 0
  fi
  populate_stage claude
  local stage
  stage="$(stage_dir claude)"
  local mp="$stage/.claude-plugin/marketplace.json"
  claude plugin marketplace add "$mp" 2>/dev/null || \
    claude plugin marketplace add "$stage" 2>/dev/null || true
  claude plugin install "${PLUGIN_NAME}@${PLUGIN_NAME}-marketplace" 2>/dev/null || \
    claude plugin install "$PLUGIN_NAME" 2>/dev/null || true

  local cache_root="${HOME}/.claude/plugins/cache"
  mkdir -p "$cache_root"
  local link_dst=""
  for cand in \
    "$cache_root/${PLUGIN_NAME}-marketplace/${PLUGIN_NAME}/$version" \
    "$cache_root/${PLUGIN_NAME}-marketplace/${PLUGIN_NAME}" \
    "$cache_root/${PLUGIN_NAME}/$version"
  do
    if [[ -e "$cand" || -L "$cand" ]]; then
      link_dst="$cand"
      break
    fi
  done
  if [[ -z "$link_dst" ]]; then
    link_dst="$cache_root/${PLUGIN_NAME}-marketplace/${PLUGIN_NAME}/$version"
    mkdir -p "$(dirname "$link_dst")"
  fi
  rm -rf "$link_dst"
  ln -s "$stage" "$link_dst"
  echo "OK Claude Code: stage linked at $link_dst"
  echo "  Next: /reload-plugins；/plugin 确认 ${PLUGIN_NAME}"
}

install_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "SKIP Codex: codex CLI not found"
    return 0
  fi
  populate_stage codex
  local stage
  stage="$(stage_dir codex)"
  codex plugin marketplace remove "$MARKETPLACE_LOCAL" >/dev/null 2>&1 || true
  codex plugin marketplace add "$stage"
  codex plugin add "${PLUGIN_NAME}@${MARKETPLACE_LOCAL}" 2>/dev/null || \
    codex plugin add "$PLUGIN_NAME" --marketplace "$MARKETPLACE_LOCAL" 2>/dev/null || true
  echo "OK Codex: marketplace → $stage (v$version)"
  echo "  Next: restart Codex / new task；Plugins 确认 ${PLUGIN_NAME}"
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
esac

if [[ "$DEV" == "1" ]]; then
  echo "done (v$version, --dev)"
else
  echo "done (v$version)"
fi
