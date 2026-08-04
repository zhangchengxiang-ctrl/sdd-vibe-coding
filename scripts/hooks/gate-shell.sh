#!/usr/bin/env bash
# Cursor/Claude beforeShellExecution gate: block production deploy without P4 marker.
# stdin: hook JSON; stdout: {permission: allow|deny|ask, ...}
set -euo pipefail
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HOOKS_DIR/lib.sh"

INPUT="$(cat || true)"
CMD="$(sdd_json_field "$INPUT" command "")"
[[ -z "$CMD" ]] && CMD="$(sdd_json_field "$INPUT" tool_input.command "")"

CWD="$(sdd_json_field "$INPUT" cwd "")"
[[ -z "$CWD" ]] && CWD="$(sdd_json_field "$INPUT" working_directory ".")"
ROOT="$(sdd_find_root "${CWD:-.}")"

# Fail-open if no command parsed (schema drift)
if [[ -z "$CMD" ]]; then
  sdd_emit_allow
  exit 0
fi

# Always allow authorize helpers and journey / falsify tooling
case "$CMD" in
  *authorize.build*|*authorize.deploy*|*wish-journey*|*record-conductor-falsify*|*require-conductor-falsify*|*preflight-rail*)
    sdd_emit_allow
    exit 0
    ;;
esac

# Production / deploy heuristics (high confidence → deny without P4)
PROD_RE='(^|[[:space:];|&])(make[[:space:]]+deploy|npm[[:space:]]+run[[:space:]]+deploy|pnpm[[:space:]]+deploy|yarn[[:space:]]+deploy|vercel[[:space:]]+([^|]*--[[:space:]]*prod|.*--prod)|fly[[:space:]]+deploy|railway[[:space:]]+up|helm[[:space:]]+upgrade|kubectl[[:space:]]+apply|kubectl[[:space:]]+rollout|terraform[[:space:]]+apply|ansible-playbook|cap[[:space:]]+production|cap[[:space:]]+prod|eb[[:space:]]+deploy|gcloud[[:space:]]+run[[:space:]]+deploy|aws[[:space:]]+ecs[[:space:]]+update-service|systemctl[[:space:]]+(restart|reload).*prod|ssh[[:space:]].*prod|scp[[:space:]].*prod|rsync[[:space:]].*prod)'

if echo "$CMD" | grep -Eiq "$PROD_RE" \
  || echo "$CMD" | grep -Eiq 'deploy.*(production|prod\b)|production.*deploy|reload.*live|live.*reload'; then
  if sdd_auth_deploy_ok "$ROOT"; then
    sdd_emit_allow
    exit 0
  fi
  sdd_emit_deny \
    "SDD Deploy P4 gate: production/deploy command blocked. Approve Deploy this turn, then: make sdd-authorize HOST=$ROOT KIND=deploy-p4" \
    "Build≠Deploy. Create .sdd/authorize.deploy-p4 (make sdd-authorize KIND=deploy-p4) only after explicit 发布/上线 + P4. Do not retry deploy."
  exit 0
fi

# Ban Codex MCP invocation patterns in shell (defense in depth)
if echo "$CMD" | grep -Eiq 'CallMcpTool.*(user-codex|\"codex\"|codex-reply)|mcp.*codex.*(exec|reply)'; then
  sdd_emit_deny \
    "SDD Codex gate: Codex MCP blocked. Use codex-dispatch.sh / make codex-dispatch." \
    "Hard gate: dispatch only via skills/dispatch-codex/scripts/codex-dispatch.sh."
  exit 0
fi

sdd_emit_allow
exit 0
