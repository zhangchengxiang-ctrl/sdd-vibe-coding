#!/usr/bin/env bash
# Host wrapper → plugin gate-shell (resolve SDD_VIBE_ROOT or local plugin install).
set -euo pipefail
resolve() {
  if [[ -n "${SDD_VIBE_ROOT:-}" && -x "${SDD_VIBE_ROOT}/scripts/hooks/gate-shell.sh" ]]; then
    printf '%s\n' "${SDD_VIBE_ROOT}/scripts/hooks/gate-shell.sh"
    return
  fi
  local c
  for c in \
    "${HOME}/.cursor/plugins/local/sdd-vibe-coding/scripts/hooks/gate-shell.sh" \
    "${HOME}/.cursor/skills/vibe-coding/../../scripts/hooks/gate-shell.sh"; do
    if [[ -x "$c" ]]; then
      printf '%s\n' "$c"
      return
    fi
  done
  # Fail-open if plugin missing
  echo '{"permission":"allow","agentMessage":"SDD hooks: plugin gate-shell.sh not found; fail-open"}'
  exit 0
}
TARGET="$(resolve)"
exec bash "$TARGET"
