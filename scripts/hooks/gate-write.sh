#!/usr/bin/env bash
# Cursor preToolUse / afterFileEdit style gate for Write|StrReplace|Delete.
# Blocks business-path edits without build authorization (scheme / journey / marker).
set -euo pipefail
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HOOKS_DIR/lib.sh"

INPUT="$(cat || true)"
TOOL="$(sdd_json_field "$INPUT" tool_name "")"
[[ -z "$TOOL" ]] && TOOL="$(sdd_json_field "$INPUT" toolName "")"
[[ -z "$TOOL" ]] && TOOL="$(sdd_json_field "$INPUT" hook_event_name "")"

PATH_CAND="$(sdd_json_field "$INPUT" tool_input.path "")"
[[ -z "$PATH_CAND" ]] && PATH_CAND="$(sdd_json_field "$INPUT" path "")"
[[ -z "$PATH_CAND" ]] && PATH_CAND="$(sdd_json_field "$INPUT" file_path "")"
[[ -z "$PATH_CAND" ]] && PATH_CAND="$(sdd_json_field "$INPUT" tool_input.file_path "")"

CWD="$(sdd_json_field "$INPUT" cwd ".")"
ROOT="$(sdd_find_root "${CWD:-.}")"

# Fail-open if we cannot resolve a path (avoid bricking agent on schema drift)
if [[ -z "$PATH_CAND" ]]; then
  sdd_emit_allow
  exit 0
fi

# Normalize to repo-relative when possible
REL="$PATH_CAND"
case "$PATH_CAND" in
  "$ROOT"/*) REL="${PATH_CAND#"$ROOT"/}" ;;
esac

# Always allow SDD control plane + docs product/specs + markdown meta
allow=0
case "$REL" in
  .sdd/*|.cursor/*|.claude/*|docs/product/*|docs/specs/*|docs/reference/*|docs/architecture/*|docs/sdd/*)
    allow=1 ;;
  AGENTS.md|CLAUDE.md|README.md|LICENSE|LICENSE.md|Makefile|.gitignore)
    allow=1 ;;
  *.md)
    # markdown outside src often OK for Shape notes; still allow top-level and docs
    case "$REL" in
      src/*|app/*|apps/*|lib/*|packages/*/src/*|backend/*|frontend/*|server/*|internal/*)
        allow=0 ;;
      *) allow=1 ;;
    esac
    ;;
esac

if [[ "$allow" == "1" ]]; then
  sdd_emit_allow
  exit 0
fi

if sdd_auth_build_ok "$ROOT"; then
  sdd_emit_allow
  exit 0
fi

# Soft mode: ask instead of deny when SDD_HOOKS_SOFT=1
if [[ "${SDD_HOOKS_SOFT:-0}" == "1" ]]; then
  sdd_emit_ask \
    "SDD write gate: $REL looks like business code without Build authorization." \
    "Need scheme confirmation or make sdd-authorize KIND=build (or advance wish-journey to planning/building). Prefer docs/product until authorized."
  exit 0
fi

sdd_emit_deny \
  "SDD write gate: blocked editing $REL without Build authorization. Confirm方案 / 开始做, then: make sdd-authorize HOST=$ROOT KIND=build" \
  "Shape may only write docs/product (etc). After 确认方案/开始做: make sdd-authorize KIND=build or wish-journey --set planning|building."
exit 0
