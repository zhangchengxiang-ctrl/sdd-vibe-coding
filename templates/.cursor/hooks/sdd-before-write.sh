#!/usr/bin/env bash
# Host wrapper → plugin gate-write.
set -euo pipefail
resolve() {
  if [[ -n "${SDD_VIBE_ROOT:-}" && -x "${SDD_VIBE_ROOT}/scripts/hooks/gate-write.sh" ]]; then
    printf '%s\n' "${SDD_VIBE_ROOT}/scripts/hooks/gate-write.sh"
    return
  fi
  local c
  for c in \
    "${HOME}/.cursor/plugins/local/sdd-vibe-coding/scripts/hooks/gate-write.sh" \
    "${HOME}/.cursor/skills/vibe-coding/../../scripts/hooks/gate-write.sh"; do
    if [[ -x "$c" ]]; then
      printf '%s\n' "$c"
      return
    fi
  done
  echo '{"permission":"allow","agentMessage":"SDD hooks: plugin gate-write.sh not found; fail-open"}'
  exit 0
}
TARGET="$(resolve)"
exec bash "$TARGET"
