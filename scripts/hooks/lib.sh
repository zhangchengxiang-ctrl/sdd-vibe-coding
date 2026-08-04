#!/usr/bin/env bash
# Shared helpers for SDD runtime hooks (no jq required — python3).
# shellcheck disable=SC2034
set -euo pipefail

sdd_json_field() {
  # Usage: sdd_json_field <json-string> <field> [default]
  local json="$1" field="$2" default="${3:-}"
  python3 -c '
import json,sys
raw=sys.argv[1]; field=sys.argv[2]; default=sys.argv[3] if len(sys.argv)>3 else ""
try:
    d=json.loads(raw) if raw.strip() else {}
except Exception:
    d={}
def dig(obj, path):
    cur=obj
    for p in path.split("."):
        if isinstance(cur, dict) and p in cur:
            cur=cur[p]
        else:
            return None
    return cur
v=dig(d, field)
if v is None:
    print(default)
elif isinstance(v, (dict, list)):
    print(json.dumps(v, ensure_ascii=False))
else:
    print(v)
' "$json" "$field" "$default"
}

sdd_find_root() {
  # Prefer explicit; else walk up for AGENTS.md; else cwd.
  local start="${1:-.}"
  start="$(cd "$start" && pwd)"
  if [[ -n "${SDD_HOST_ROOT:-}" && -d "${SDD_HOST_ROOT}" ]]; then
    cd "$SDD_HOST_ROOT" && pwd
    return
  fi
  local d="$start"
  while true; do
    if [[ -f "$d/AGENTS.md" || -d "$d/.sdd" || -d "$d/docs/specs" ]]; then
      printf '%s\n' "$d"
      return
    fi
    local parent
    parent="$(dirname "$d")"
    [[ "$parent" == "$d" ]] && break
    d="$parent"
  done
  printf '%s\n' "$start"
}

sdd_plugin_root() {
  if [[ -n "${SDD_VIBE_ROOT:-}" && -d "${SDD_VIBE_ROOT}/scripts/hooks" ]]; then
    printf '%s\n' "$SDD_VIBE_ROOT"
    return
  fi
  local cand
  for cand in \
    "${HOME}/.cursor/plugins/local/sdd-vibe-coding" \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; do
    if [[ -d "$cand/scripts/hooks" ]]; then
      printf '%s\n' "$cand"
      return
    fi
  done
  printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

sdd_auth_build_ok() {
  local root="$1"
  [[ "${SDD_BUILD_AUTHORIZED:-0}" == "1" || "${RAIL_AUTHORIZED:-0}" == "1" ]] && return 0
  [[ -f "$root/.sdd/authorize.build" ]] && return 0
  # Journey phases that imply build authorization
  local f phase
  shopt -s nullglob
  for f in "$root"/.sdd/journey/*.env; do
    # shellcheck disable=SC1090
    phase="$(grep -E '^PHASE=' "$f" 2>/dev/null | head -1 | cut -d= -f2- | tr -d \"\')"
    case "$phase" in
      planning|building|awaiting-falsify|verifying|repairing) return 0 ;;
    esac
  done
  shopt -u nullglob
  return 1
}

sdd_auth_deploy_ok() {
  local root="$1"
  [[ "${SDD_DEPLOY_AUTHORIZED:-0}" == "1" ]] && return 0
  local f="$root/.sdd/authorize.deploy-p4"
  [[ -f "$f" ]] || return 1
  # Fresh within 24h (mtime)
  local now mt age
  now=$(date +%s)
  mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f")
  age=$((now - mt))
  (( age < 86400 ))
}

sdd_emit_allow() {
  printf '%s\n' '{"permission":"allow"}'
}

sdd_emit_deny() {
  local user_msg="$1" agent_msg="${2:-$1}"
  python3 -c 'import json,sys
u,a=sys.argv[1],sys.argv[2]
print(json.dumps({
  "permission":"deny",
  "userMessage":u,"agentMessage":a,
  "user_message":u,"agent_message":a,
},ensure_ascii=False))' "$user_msg" "$agent_msg"
}

sdd_emit_ask() {
  local user_msg="$1" agent_msg="${2:-$1}"
  python3 -c 'import json,sys
u,a=sys.argv[1],sys.argv[2]
print(json.dumps({
  "permission":"ask",
  "userMessage":u,"agentMessage":a,
  "user_message":u,"agent_message":a,
},ensure_ascii=False))' "$user_msg" "$agent_msg"
}
