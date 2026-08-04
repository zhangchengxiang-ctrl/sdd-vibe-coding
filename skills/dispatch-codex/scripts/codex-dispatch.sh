#!/usr/bin/env bash
# CLI dispatcher for conductor→Codex construction units.
# Sets approval_policy=never, wall-clock timeout, optional JSONL event log.
#
# Usage:
#   bash skills/dispatch-codex/scripts/codex-dispatch.sh \
#     --cwd /path/to/host --unit plan|build|goal -- [prompt...]
#   echo "$PROMPT" | bash …/codex-dispatch.sh --cwd … --unit build
#
# Env overrides:
#   CODEX_DISPATCH_TIMEOUT_SEC   default: plan=900, build=1200, goal=3600
#   CODEX_DISPATCH_MODEL         default: gpt-5.6-sol
#   CODEX_DISPATCH_EFFORT        default: medium (goal→high)
#   CODEX_DISPATCH_SANDBOX       default: plan=workspace-write, else danger-full-access
#   CODEX_DISPATCH_LOG_DIR       default: <cwd>/.codex-dispatch-logs
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: codex-dispatch.sh --cwd DIR --unit plan|build|goal [options] [-- PROMPT]

Required:
  --cwd DIR              Host repo root (Codex -C)
  --unit plan|build|goal Completion unit (sets timeout/sandbox/effort defaults)

Options:
  --effort medium|high   Reasoning effort (default: medium; goal→high)
  --model NAME           Model (default: gpt-5.6-sol; terra/luna rejected)
  --sandbox MODE         read-only|workspace-write|danger-full-access
  --timeout SEC          Wall clock limit (kills process on expiry)
  --spec ID              Spec id under SDD docs/specs (required for build/goal unless SKIP)
  --slice ID             Build: required slice id (also accept SLICE_ID= in prompt)
  --json                 Stream JSONL events to stdout + log file
  --no-json              Final message only (default: --json on)
  --log-dir DIR          Event/log directory
  -h, --help             Show help

Prompt: remaining args after --, or stdin if no args.
Always sets approval_policy=never (cannot be overridden).
Plan: injects wish-path hard gates (no mid-flow 待批准); requires --spec;
  after Codex ok runs assert_plan_artifacts.py (SKIP_PLAN_ARTIFACT_CHECK=1 bypass).
Build/Goal runs skills/spec/scripts/check_spec.py first (SKIP_SPEC_CHECK=1 to bypass).
Build: one longitudinal slice only (multi-slice → --unit goal + GOAL_APPROVED=1).
Goal: requires env GOAL_APPROVED=1.
After Build ok: conductor must write <log-dir>/<run-id>_falsify.log with VERDICT: PASS.
EOF
}

die() { echo "codex-dispatch: $*" >&2; exit 2; }

CWD=""
UNIT=""
EFFORT=""
MODEL="${CODEX_DISPATCH_MODEL:-gpt-5.6-sol}"
SANDBOX=""
TIMEOUT_SEC=""
SPEC_ID="${CODEX_DISPATCH_SPEC:-}"
SLICE_ID="${CODEX_DISPATCH_SLICE:-}"
JSON=1
LOG_DIR="${CODEX_DISPATCH_LOG_DIR:-}"
PROMPT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --unit) UNIT="${2:-}"; shift 2 ;;
    --effort) EFFORT="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --sandbox) SANDBOX="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT_SEC="${2:-}"; shift 2 ;;
    --spec) SPEC_ID="${2:-}"; shift 2 ;;
    --slice) SLICE_ID="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --no-json) JSON=0; shift ;;
    --log-dir) LOG_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; PROMPT_ARGS=("$@"); break ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      PROMPT_ARGS+=("$1"); shift
      ;;
  esac
done

[[ -n "$CWD" ]] || die "--cwd is required"
[[ -d "$CWD" ]] || die "cwd is not a directory: $CWD"
CWD="$(cd "$CWD" && pwd)"

[[ -n "$UNIT" ]] || die "--unit plan|build|goal is required"
case "$UNIT" in
  plan|build|goal) ;;
  *) die "--unit must be plan|build|goal (got: $UNIT)" ;;
esac

case "$MODEL" in
  gpt-5.6-sol) ;;
  gpt-5.6-terra|gpt-5.6-luna|*"terra"*|*"luna"*)
    die "model must be gpt-5.6-sol (got '$MODEL')"
    ;;
  *)
    if [[ "$MODEL" == *terra* || "$MODEL" == *luna* ]]; then
      die "model must be gpt-5.6-sol (got '$MODEL')"
    fi
    echo "codex-dispatch: warning: non-default model '$MODEL' (expected gpt-5.6-sol)" >&2
    ;;
esac

if [[ -z "$EFFORT" ]]; then
  if [[ "$UNIT" == "goal" ]]; then
    EFFORT="${CODEX_DISPATCH_EFFORT:-high}"
  else
    EFFORT="${CODEX_DISPATCH_EFFORT:-medium}"
  fi
fi
case "$EFFORT" in
  medium|high) ;;
  low)
    die "effort must be medium or high (got low)"
    ;;
  *)
    die "effort must be medium|high (got: $EFFORT)"
    ;;
esac

if [[ -z "$SANDBOX" ]]; then
  if [[ -n "${CODEX_DISPATCH_SANDBOX:-}" ]]; then
    SANDBOX="$CODEX_DISPATCH_SANDBOX"
  elif [[ "$UNIT" == "plan" ]]; then
    SANDBOX="workspace-write"
  else
    SANDBOX="danger-full-access"
  fi
fi
case "$SANDBOX" in
  read-only|workspace-write|danger-full-access) ;;
  *) die "invalid sandbox: $SANDBOX" ;;
esac

if [[ -z "$TIMEOUT_SEC" ]]; then
  if [[ -n "${CODEX_DISPATCH_TIMEOUT_SEC:-}" ]]; then
    TIMEOUT_SEC="$CODEX_DISPATCH_TIMEOUT_SEC"
  else
    case "$UNIT" in
      plan) TIMEOUT_SEC=900 ;;
      build) TIMEOUT_SEC=1200 ;;
      goal) TIMEOUT_SEC=3600 ;;
    esac
  fi
fi
[[ "$TIMEOUT_SEC" =~ ^[1-9][0-9]*$ ]] || die "timeout must be positive integer seconds"

if [[ ${#PROMPT_ARGS[@]} -gt 0 ]]; then
  PROMPT="$(printf '%s ' "${PROMPT_ARGS[@]}")"
  PROMPT="${PROMPT% }"
elif [[ ! -t 0 ]]; then
  PROMPT="$(cat)"
else
  die "prompt required (args or stdin)"
fi
[[ -n "${PROMPT//[[:space:]]/}" ]] || die "prompt is empty"

# --- CLI authorization block (all units): kill ask-back / mid-flow 待批准 ---
# Overrides host AGENTS "plan in chat then wait for 批准" and co-authoring skills.
AUTH_BLOCK="$(cat <<'AUTH'
## CLI dispatch authorization (HARD · non-interactive)
You are running under `codex exec` with `approval_policy=never`. There is NO human on the other end of this turn.

1. **Already authorized:** The conductor/wish-path already approved this unit. Do NOT wait for「批准」「可以开始」「go ahead」. Do NOT paste an「执行计划（待批准）」and stop.
2. **Host AGENTS override:** If AGENTS.md says new capabilities need a plan-in-chat + explicit approval before execution, that gate is **already satisfied by this CLI dispatch**. Proceed to write/implement immediately.
3. **Forbidden skills/behaviors:** Do NOT use `doc-coauthoring` or any co-authoring / ask-user / confirm-before-write workflow. Do NOT ask clarifying questions to the user. Prefer `Unverified` + scoped proceed, or durable fail state — never a question ending the turn.
4. **Output shape:** Tools first (write/patch/test). Final message = short status + evidence paths only. Zero questions. Zero「请确认」「是否继续」「需要你决定」unless the unit is truly blocked on missing secrets (then state `blocked` + exact missing env — still no approval ask).
5. **Success = disk/repo change** matching Done when — not a chat plan.
AUTH
)"
PROMPT="${AUTH_BLOCK}

${PROMPT}"

# --- Wish-path Plan extras (disk Done when) ---
if [[ "$UNIT" == "plan" ]]; then
  PLAN_PREAMBLE="$(cat <<'PREAMBLE'
## Plan unit Done when (disk)
- Product scheme is already confirmed upstream.
- MUST write Spec files now: docs/specs/<SPEC_ID>/{VERSION.md,contract.md,tests.md,plan.md,run.md}
- Chat-only plans are a FAILURE (conductor will assert_plan_artifacts and fail this dispatch).
- After writing: `ls -la docs/specs/<SPEC_ID>/`
PREAMBLE
)"
  if [[ -n "$SPEC_ID" ]]; then
    PLAN_PREAMBLE="${PLAN_PREAMBLE//<SPEC_ID>/$SPEC_ID}"
  fi
  PROMPT="${PROMPT}

${PLAN_PREAMBLE}"
fi

# --- Unit / slice gates ---
if [[ "$UNIT" == "goal" && "${GOAL_APPROVED:-0}" != "1" ]]; then
  die "goal requires GOAL_APPROVED=1 (user asked for continuous multi-slice / full Spec Goal)"
fi

if [[ "$UNIT" == "plan" ]]; then
  if [[ -z "$SPEC_ID" && "${SKIP_PLAN_ARTIFACT_CHECK:-0}" != "1" ]]; then
    die "plan requires --spec <id> so post-dispatch artifact check can run (or SKIP_PLAN_ARTIFACT_CHECK=1)"
  fi
fi

if [[ "$UNIT" == "build" ]]; then
  if echo "$PROMPT" | grep -Eiq \
    '剩余切片|all[[:space:]]+slices|全部切片|整份[[:space:]]*Spec[[:space:]]*(做完|完成)|multiple[[:space:]]+slices|多片连做|S1[[:space:]]*[|｜,/][[:space:]]*S2|S2[[:space:]]*[~～-][[:space:]]*S[0-9]'; then
    die "build unit = one slice only; for multi-slice use --unit goal + GOAL_APPROVED=1"
  fi
  if [[ -z "$SLICE_ID" ]]; then
    if echo "$PROMPT" | grep -Eqi 'SLICE_ID[[:space:]]*=[[:space:]]*[[:alnum:]_.-]+'; then
      SLICE_ID="$(echo "$PROMPT" | grep -Eio 'SLICE_ID[[:space:]]*=[[:space:]]*[[:alnum:]_.-]+' | head -1 | sed -E 's/.*=[[:space:]]*//')"
    elif echo "$PROMPT" | grep -Eqi '(^|[[:space:]])S[0-9]+([[:space:]]|$|[：:])'; then
      SLICE_ID="$(echo "$PROMPT" | grep -Eio '(^|[[:space:]])S[0-9]+' | head -1 | tr -d '[:space:]')"
    fi
  fi
  [[ -n "$SLICE_ID" ]] || die "build requires --slice <id> or SLICE_ID=/S# in prompt (one longitudinal slice)"
  if ! echo "$PROMPT" | grep -Eqi "SLICE_ID[[:space:]]*=[[:space:]]*${SLICE_ID}|切片[^[:alnum:]]*${SLICE_ID}|${SLICE_ID}"; then
    PROMPT="SLICE_ID=${SLICE_ID}
${PROMPT}"
  fi
  echo "codex-dispatch: build slice=$SLICE_ID" >&2
fi

# --- Spec static gate (Build/Goal) ---
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK_SPEC="$PLUGIN_ROOT/skills/spec/scripts/check_spec.py"
if [[ "$UNIT" == "build" || "$UNIT" == "goal" ]]; then
  if [[ "${SKIP_SPEC_CHECK:-0}" == "1" ]]; then
    echo "codex-dispatch: WARN SKIP_SPEC_CHECK=1 — maintainer-only bypass; never in user sessions" >&2
  else
    [[ -f "$CHECK_SPEC" ]] || die "check_spec.py not found at $CHECK_SPEC"
    if [[ -z "$SPEC_ID" ]]; then
      die "build/goal requires --spec <id> (or CODEX_DISPATCH_SPEC); refuse dispatch without Spec gate"
    fi
    echo "codex-dispatch: preflight check_spec ($SPEC_ID)" >&2
    if ! python3 "$CHECK_SPEC" "$CWD" "$SPEC_ID" --skip-agents; then
      die "check_spec failed for '$SPEC_ID' — refuse Codex $UNIT (fix Spec or SKIP_SPEC_CHECK=1)"
    fi
  fi
fi

command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH"
command -v timeout >/dev/null 2>&1 || die "GNU timeout (coreutils) not found on PATH"

if [[ -z "$LOG_DIR" ]]; then
  LOG_DIR="$CWD/.codex-dispatch-logs"
fi
mkdir -p "$LOG_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="${UNIT}_${STAMP}_$$"
LOG_FILE="$LOG_DIR/${RUN_ID}.jsonl"
META_FILE="$LOG_DIR/${RUN_ID}.meta.txt"

{
  echo "cwd=$CWD"
  echo "unit=$UNIT"
  echo "model=$MODEL"
  echo "effort=$EFFORT"
  echo "sandbox=$SANDBOX"
  echo "approval_policy=never"
  echo "timeout_sec=$TIMEOUT_SEC"
  echo "json=$JSON"
  echo "started_at=$STAMP"
  echo "log_file=$LOG_FILE"
  echo "run_id=$RUN_ID"
  [[ -n "$SPEC_ID" ]] && echo "spec=$SPEC_ID"
  [[ -n "$SLICE_ID" ]] && echo "slice=$SLICE_ID"
  echo "falsify_log=$LOG_DIR/${RUN_ID}_falsify.log"
} >"$META_FILE"

echo "codex-dispatch: unit=$UNIT model=$MODEL effort=$EFFORT sandbox=$SANDBOX timeout=${TIMEOUT_SEC}s" >&2
echo "codex-dispatch: approval_policy=never (forced)" >&2
echo "codex-dispatch: log=$LOG_FILE" >&2

# Build argv. approval_policy is always never.
CMD=(
  timeout --signal=TERM --kill-after=30s "${TIMEOUT_SEC}s"
  codex exec
  -C "$CWD"
  -s "$SANDBOX"
  -m "$MODEL"
  -c "model_reasoning_effort=\"${EFFORT}\""
  -c 'approval_policy="never"'
  --skip-git-repo-check
)

if [[ "$JSON" == "1" ]]; then
  CMD+=(--json)
fi

STDERR_FILE="$LOG_DIR/${RUN_ID}.stderr.log"
set +e
# Feed prompt on stdin; tee via process substitution; $? is timeout/codex.
"${CMD[@]}" < <(printf '%s\n' "$PROMPT") \
  > >(tee -a "$LOG_FILE") \
  2> >(tee -a "$STDERR_FILE" >&2)
STATUS=$?
set -e
# Wait for tee process substitutions to flush.
wait 2>/dev/null || true

{
  echo "finished_at=$(date -u +%Y%m%dT%H%M%SZ)"
  echo "exit_status=$STATUS"
} >>"$META_FILE"

if [[ $STATUS -eq 124 || $STATUS -eq 137 ]]; then
  echo "codex-dispatch: TIMED OUT after ${TIMEOUT_SEC}s (exit $STATUS)" >&2
  echo "codex-dispatch: inspect repo artifacts and accept against the repo." >&2
  echo "codex-dispatch: meta=$META_FILE" >&2
  exit 124
fi

if [[ $STATUS -ne 0 ]]; then
  echo "codex-dispatch: failed (exit $STATUS); meta=$META_FILE" >&2
  exit "$STATUS"
fi

# Plan: Codex exit 0 is not enough — Spec must be on disk (wish-path).
if [[ "$UNIT" == "plan" ]]; then
  ASSERT_PLAN="$PLUGIN_ROOT/skills/dispatch-codex/scripts/assert_plan_artifacts.py"
  if [[ "${SKIP_PLAN_ARTIFACT_CHECK:-0}" == "1" ]]; then
    echo "codex-dispatch: WARN SKIP_PLAN_ARTIFACT_CHECK=1 — maintainer-only bypass" >&2
  else
    [[ -f "$ASSERT_PLAN" ]] || die "assert_plan_artifacts.py not found at $ASSERT_PLAN"
    echo "codex-dispatch: postflight assert_plan_artifacts ($SPEC_ID)" >&2
    if ! python3 "$ASSERT_PLAN" "$CWD" "$SPEC_ID"; then
      echo "codex-dispatch: Plan produced no Spec on disk (chat-only / 待批准) — treating as failure" >&2
      echo "exit_status=2" >>"$META_FILE"
      exit 2
    fi
  fi
fi

echo "codex-dispatch: ok; meta=$META_FILE" >&2
if [[ "$UNIT" == "build" || "$UNIT" == "goal" ]]; then
  echo "codex-dispatch: NEXT — conductor falsify → tee to $LOG_DIR/${RUN_ID}_falsify.log" >&2
  echo "codex-dispatch: log must contain a line: VERDICT: ${SLICE_ID:-slice} PASS" >&2
  echo "codex-dispatch: then: bash skills/dispatch-codex/scripts/require-conductor-falsify.sh --log-dir $LOG_DIR --run-id $RUN_ID" >&2
fi
exit 0
