#!/usr/bin/env bash
# Codex dispatch environment preflight. Catches the two failure modes that made
# real dispatches die for non-capability reasons:
#   1. the host path is not registered as a trusted project → unattended runs can
#      block on a trust prompt (see also `--dangerously-bypass-hook-trust`);
#   2. the AGENTS.md chain exceeds `project_doc_max_bytes` (default 32 KiB) → Codex
#      silently truncates the contracts the dispatch payload relies on.
#
# Usage: bash scripts/codex-preflight.sh [--cwd DIR]
# Exit 0 ok · 1 blocking finding · 2 usage
set -uo pipefail

CWD="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "codex-preflight: unknown option $1" >&2; exit 2 ;;
  esac
done
[[ -d "$CWD" ]] || { echo "codex-preflight: not a directory: $CWD" >&2; exit 2; }
CWD="$(cd "$CWD" && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME:-}/.codex}"
CONF="$CODEX_HOME/config.toml"
fail=0
ok()   { echo "OK: $*"; }
bad()  { echo "FAIL: $*" >&2; fail=1; }
warn() { echo "WARN: $*" >&2; }

# --- 1. binaries -------------------------------------------------------------
if command -v codex >/dev/null 2>&1; then
  ok "codex on PATH ($(codex --version 2>/dev/null | head -1))"
else
  bad "codex not on PATH — dispatch is impossible, report Blocked rather than self-implementing"
fi
command -v timeout >/dev/null 2>&1 \
  && ok "GNU timeout present (wall-clock guard)" \
  || bad "GNU timeout missing — codex-dispatch.sh cannot bound a run"

# --- 2. project trust --------------------------------------------------------
if [[ -f "$CONF" ]]; then
  trusted=""
  probe="$CWD"
  while :; do
    if grep -Fq "[projects.\"$probe\"]" "$CONF" 2>/dev/null; then trusted="$probe"; break; fi
    parent="$(dirname "$probe")"
    [[ "$parent" == "$probe" ]] && break
    probe="$parent"
  done
  if [[ -n "$trusted" ]]; then
    ok "trusted project entry covers $CWD (matched [projects.\"$trusted\"])"
  else
    bad "no [projects.\"…\"] entry covers $CWD — add to $CONF:

[projects.\"$CWD\"]
trust_level = \"trusted\"
"
  fi
else
  bad "no $CONF — Codex was never configured here; trust cannot be verified"
fi

# --- 3. AGENTS.md chain size vs project_doc_max_bytes ------------------------
cap="$(grep -oE '^[[:space:]]*project_doc_max_bytes[[:space:]]*=[[:space:]]*[0-9]+' "$CONF" 2>/dev/null \
        | grep -oE '[0-9]+$' | head -1)"
cap="${cap:-32768}"
total=0
chain=""
for g in "$CODEX_HOME/AGENTS.override.md" "$CODEX_HOME/AGENTS.md"; do
  if [[ -f "$g" ]]; then
    n=$(wc -c <"$g"); total=$((total+n)); chain="$chain\n  $n  $g"; break
  fi
done
# One file per directory, repo root → cwd. HOST is normally the repo root.
root="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")"
d="$root"
while :; do
  for f in "$d/AGENTS.override.md" "$d/AGENTS.md"; do
    if [[ -f "$f" ]]; then
      n=$(wc -c <"$f"); total=$((total+n)); chain="$chain\n  $n  $f"; break
    fi
  done
  [[ "$d" == "$CWD" ]] && break
  next="$d/$(realpath --relative-to="$d" "$CWD" 2>/dev/null | cut -d/ -f1)"
  [[ "$next" == "$d" || ! -d "$next" ]] && break
  d="$next"
done
if [[ "$total" -eq 0 ]]; then
  bad "no AGENTS.md for $CWD — the dispatch payload relies on host contracts Codex cannot see"
elif [[ "$total" -gt "$cap" ]]; then
  bad "AGENTS.md chain is ${total}B > project_doc_max_bytes ${cap}B — Codex truncates it.
     Split the host AGENTS.md and keep Read pointers instead of inlined contract text.
     Chain:$(printf '%b' "$chain")"
else
  ok "AGENTS.md chain ${total}B / ${cap}B$(printf '%b' "$chain")"
fi

# --- 4. tier profiles (informational) ---------------------------------------
profs="$(ls -1 "$CODEX_HOME"/sdd-*.config.toml 2>/dev/null | wc -l)"
if [[ "$profs" -gt 0 ]]; then
  ok "$profs sdd-* tier profile(s) in $CODEX_HOME (use codex-dispatch.sh --profile NAME)"
else
  warn "no $CODEX_HOME/sdd-*.config.toml tier profiles — dispatch falls back to per-unit defaults"
fi

echo "--- codex-preflight: fail=$fail ---"
exit "$fail"
