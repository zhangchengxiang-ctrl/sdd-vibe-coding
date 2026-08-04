#!/usr/bin/env bash
set -euo pipefail
resolve() {
  if [[ -n "${SDD_VIBE_ROOT:-}" && -x "${SDD_VIBE_ROOT}/scripts/hooks/gate-shell.sh" ]]; then
    printf '%s\n' "${SDD_VIBE_ROOT}/scripts/hooks/gate-shell.sh"; return
  fi
  local c
  for c in "${HOME}/.cursor/plugins/local/sdd-vibe-coding/scripts/hooks/gate-shell.sh"; do
    [[ -x "$c" ]] && { printf '%s\n' "$c"; return; }
  done
  echo '{"permission":"allow","agentMessage":"SDD hooks: plugin missing; fail-open"}'
  exit 0
}
exec bash "$(resolve)"
