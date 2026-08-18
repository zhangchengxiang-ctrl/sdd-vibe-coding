#!/usr/bin/env bash
# CLI dispatcher for conductor→Codex construction units.
# Sets approval_policy=never, wall-clock timeout, optional JSONL event log.
#
# Usage:
#   bash skills/dispatch-codex/scripts/codex-dispatch.sh \
#     --cwd /path/to/host --unit plan|build -- [prompt...]
#   echo "$PROMPT" | bash …/codex-dispatch.sh --cwd … --unit build
#
# Env overrides:
#   CODEX_DISPATCH_TIMEOUT_SEC   default: plan=900, build=1200
#   CODEX_DISPATCH_MODEL         default: gpt-5.6-sol
#   CODEX_DISPATCH_EFFORT        default: medium
#   CODEX_DISPATCH_SANDBOX       default: plan=workspace-write, else danger-full-access
#   CODEX_DISPATCH_LOG_DIR       default: <cwd>/.codex-dispatch-logs
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: codex-dispatch.sh --cwd DIR --unit plan|build [options] [-- PROMPT]

Required:
  --cwd DIR              Host repo root (Codex -C)
  --unit plan|build      Completion unit (sets timeout/sandbox/effort defaults)

Options:
  --effort LEVEL         minimal|low|medium|high|xhigh|max (default: medium)
  --model NAME           gpt-5.6-sol|terra|luna
                         (default: build/audit→terra, else sol — tier is a quota lever)
  --profile NAME         Codex config profile (-p NAME); tier presets live in
                         $CODEX_HOME/<name>.config.toml, not in this script
  --sandbox MODE         read-only|workspace-write|danger-full-access
  --timeout SEC          Wall clock limit (kills process on expiry)
  --spec ID              Spec id under SDD docs/specs (required for build unless SKIP)
  --slice ID             Build: slice or comma list S1,S2 (one dispatch unit)
  --dispatch-id ID       Optional D id (also accept DISPATCH_ID= in prompt)
  --run-id-file PATH     Write RUN_ID here as soon as it is assigned (no log scan)
  --json                 Stream JSONL events to stdout + log file
  --no-json              Final message only (default: --json on)
  --log-dir DIR          Event/log directory
  -h, --help             Show help

Prompt: remaining args after --, or stdin if no args.
Always sets approval_policy=never (cannot be overridden).
Plan: injects wish-path hard gates (no mid-flow 待批准); requires --spec;
  after Codex ok runs assert_plan_artifacts.py (SKIP_PLAN_ARTIFACT_CHECK=1 bypass).
Build runs skills/spec/scripts/check_spec.py first (SKIP_SPEC_CHECK=1 to bypass).
Build: one dispatch unit == one plan.md slice (A == D).
Several slices in one exec → fail. A == D: one slice per exec.
After Build ok: the conductor replays the frozen Oracles (ship.sh --from-meta <meta>).
EOF
}

die() { echo "codex-dispatch: $*" >&2; exit 2; }

CWD=""
UNIT=""
EFFORT=""
MODEL="${CODEX_DISPATCH_MODEL:-}"   # empty → resolved per unit after arg parsing
PROFILE="${CODEX_DISPATCH_PROFILE:-}"
MODEL_EXPLICIT=""
EFFORT_EXPLICIT=""
SANDBOX=""
TIMEOUT_SEC=""
SPEC_ID="${CODEX_DISPATCH_SPEC:-}"
SLICE_ID="${CODEX_DISPATCH_SLICE:-}"
DISPATCH_ID="${CODEX_DISPATCH_DISPATCH_ID:-}"
RUN_ID_FILE="${CODEX_DISPATCH_RUN_ID_FILE:-}"
JSON=1
LOG_DIR="${CODEX_DISPATCH_LOG_DIR:-}"
PROMPT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --unit) UNIT="${2:-}"; shift 2 ;;
    --effort) EFFORT="${2:-}"; EFFORT_EXPLICIT=1; shift 2 ;;
    --model) MODEL="${2:-}"; MODEL_EXPLICIT=1; shift 2 ;;
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --sandbox) SANDBOX="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT_SEC="${2:-}"; shift 2 ;;
    --spec) SPEC_ID="${2:-}"; shift 2 ;;
    --slice) SLICE_ID="${2:-}"; shift 2 ;;
    --dispatch-id) DISPATCH_ID="${2:-}"; shift 2 ;;
    --run-id-file) RUN_ID_FILE="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --no-json) JSON=0; shift ;;   # gated below: dispatch units require the event stream
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

[[ -n "$UNIT" ]] || die "--unit plan|build is required"
case "$UNIT" in
  plan|build) ;;
  # `goal` is gone: it existed so a whole Spec could be pushed through one exec when the
  # packer judged it small enough by an estimated token peak. A == D now — one slice, one
  # exec — and the estimate was never computable in the first place.
  goal) die "--unit goal is gone (A == D): dispatch one slice per exec with --unit build --slice S<n>" ;;
  *) die "--unit must be plan|build (got: $UNIT)" ;;
esac

# Tier is a subscription-quota lever, not a quality lever. Rejecting the cheaper
# tiers here is what pinned all 75 real dispatches to Sol and burned the credit
# window (6 of them died on `usage limit` before reaching the model at all).
if [[ -z "$MODEL" ]]; then
  case "$UNIT" in
    build|audit) MODEL="gpt-5.6-terra" ;;
    *)           MODEL="gpt-5.6-sol" ;;
  esac
fi
case "$MODEL" in
  gpt-5.6-sol|gpt-5.6-terra|gpt-5.6-luna) ;;
  *)
    echo "codex-dispatch: warning: non-default model '$MODEL' (known tiers: gpt-5.6-sol|terra|luna)" >&2
    ;;
esac

# One default tier for every unit: the `goal` unit that wanted `high` is gone, and escalating
# effort was measured to make Oracle executability worse (3/6 at medium vs 3/8 at high).
if [[ -z "$EFFORT" ]]; then
  EFFORT="${CODEX_DISPATCH_EFFORT:-medium}"
fi
case "$EFFORT" in
  minimal|low|medium|high|xhigh|max) ;;
  *)
    die "effort must be minimal|low|medium|high|xhigh|max (got: $EFFORT)"
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
if [[ "$UNIT" == "plan" ]]; then
  if [[ -z "$SPEC_ID" && "${SKIP_PLAN_ARTIFACT_CHECK:-0}" != "1" ]]; then
    die "plan requires --spec <id> so post-dispatch artifact check can run (or SKIP_PLAN_ARTIFACT_CHECK=1)"
  fi
fi

if [[ "$UNIT" == "build" ]]; then
  if [[ -z "$DISPATCH_ID" ]] && echo "$PROMPT" | grep -Eqi 'DISPATCH_ID[[:space:]]*=[[:space:]]*[[:alnum:]_.-]+'; then
    DISPATCH_ID="$(echo "$PROMPT" | grep -Eio 'DISPATCH_ID[[:space:]]*=[[:space:]]*[[:alnum:]_.-]+' | head -1 | sed -E 's/.*=[[:space:]]*//')"
  fi
  if [[ -z "$SLICE_ID" ]] && echo "$PROMPT" | grep -Eqi 'SLICE_IDS[[:space:]]*=[[:space:]]*[[:alnum:]_.,-]+'; then
    SLICE_ID="$(echo "$PROMPT" | grep -Eio 'SLICE_IDS[[:space:]]*=[[:space:]]*[[:alnum:]_.,-]+' | head -1 | sed -E 's/.*=[[:space:]]*//')"
  fi
  packed=0
  if [[ -n "$DISPATCH_ID" ]] || echo "$SLICE_ID" | grep -q ',' \
    || echo "$PROMPT" | grep -Eqi 'DISPATCH_ID[[:space:]]*=|SLICE_IDS[[:space:]]*='; then
    packed=1
  fi
  if [[ "$packed" != "1" ]] && echo "$PROMPT" | grep -Eiq \
    '剩余切片|all[[:space:]]+slices|全部切片|整份[[:space:]]*Spec[[:space:]]*(做完|完成)|multiple[[:space:]]+slices|多片连做|S1[[:space:]]*[|｜,/][[:space:]]*S2|S2[[:space:]]*[~～-][[:space:]]*S[0-9]'; then
    die "this prompt asks for several slices in one exec — A == D: dispatch one slice per \
exec with --slice S<n>, and let wish-orchestrate wave them"
  fi
  if [[ -z "$SLICE_ID" ]]; then
    if echo "$PROMPT" | grep -Eqi 'SLICE_ID[[:space:]]*=[[:space:]]*[[:alnum:]_.-]+'; then
      SLICE_ID="$(echo "$PROMPT" | grep -Eio 'SLICE_ID[[:space:]]*=[[:space:]]*[[:alnum:]_.-]+' | head -1 | sed -E 's/.*=[[:space:]]*//')"
    elif echo "$PROMPT" | grep -Eqi '(^|[[:space:]])S[0-9]+([[:space:]]|$|[：:])'; then
      SLICE_ID="$(echo "$PROMPT" | grep -Eio '(^|[[:space:]])S[0-9]+' | head -1 | tr -d '[:space:]')"
    fi
  fi
  [[ -n "$SLICE_ID" || -n "$DISPATCH_ID" ]] \
    || die "build requires --slice / SLICE_IDS / DISPATCH_ID (one dispatch unit)"
  # Hard, structural version of the "no unbounded multi-slice" rule. The prose-and-regex
  # version above never fired: a real dispatch went out with slices=S2,S4,S3,S5 and
  # timed out at the 20-minute wall (p90 of all 75 dispatches == the timeout ceiling).
  for tok in $(printf '%s' "$SLICE_ID" | tr ',' ' '); do
    [[ "$tok" =~ ^[A-Za-z][A-Za-z0-9_.-]*$ ]] \
      || die "malformed slice token '$tok' in --slice '$SLICE_ID'"
  done
  # Count what the tokeniser splits on, not just commas: `--slice $'S1 S2'` validated both
  # tokens, counted one, and shipped `SLICE_ID=S1 S2` into a single exec.
  slice_n="$(printf '%s' "$SLICE_ID" | tr ',[:space:]' '\n' | grep -c '[^[:space:]]' || true)"
  # A == D, so there is no packed unit for a --dispatch-id to name any more. Multi-slice used
  # to be allowed with one, which is how slices=S2,S4,S3,S5 went out and timed out at the wall
  # (p90 across all 75 real dispatches equalled the timeout ceiling). One slice, one exec.
  if [[ "${slice_n:-0}" -gt 1 ]]; then
    die "multi-slice dispatch ($SLICE_ID) is refused: A == D means one slice per exec. Dispatch \
them separately, or run wish-orchestrate --parallel N to wave them with the edit lock applied"
  fi
  # A payload naming more than one slice is the same refusal by another route: marking the
  # prompt "packed" used to disable the prose check without anyone comparing it to --slice.
  payload_ids="$(printf '%s' "$PROMPT" | grep -Eio 'SLICE_IDS[[:space:]]*=[[:space:]]*[[:alnum:]_.,-]+' | head -1 | sed -E 's/.*=[[:space:]]*//')"
  if [[ -n "$payload_ids" ]]; then
    payload_n="$(printf '%s' "$payload_ids" | tr ',[:space:]' '\n' | grep -c '[^[:space:]]' || true)"
    [[ "${payload_n:-0}" -le 1 ]] || die "payload declares SLICE_IDS=$payload_ids — A == D means \
one slice per exec, whatever --slice says. Dispatch them separately."
  fi
  if [[ -n "$SLICE_ID" ]] && ! echo "$PROMPT" | grep -Eqi "SLICE_ID[[:space:]]*=|SLICE_IDS[[:space:]]*=|${SLICE_ID%%,*}"; then
    PROMPT="SLICE_ID=${SLICE_ID}
${PROMPT}"
  fi
  echo "codex-dispatch: build slice=${SLICE_ID:-?} dispatch_id=${DISPATCH_ID:-}" >&2
fi

# --- Spec static gate (Build) ---
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK_SPEC="$PLUGIN_ROOT/skills/spec/scripts/check_spec.py"
if [[ "$UNIT" == "build" ]]; then
  if [[ "${SKIP_SPEC_CHECK:-0}" == "1" ]]; then
    echo "codex-dispatch: WARN SKIP_SPEC_CHECK=1 — maintainer-only bypass; never in user sessions" >&2
  else
    [[ -f "$CHECK_SPEC" ]] || die "check_spec.py not found at $CHECK_SPEC"
    if [[ -z "$SPEC_ID" ]]; then
      die "build requires --spec <id> (or CODEX_DISPATCH_SPEC); refuse dispatch without Spec gate"
    fi
    echo "codex-dispatch: preflight check_spec ($SPEC_ID)" >&2
    if ! python3 "$CHECK_SPEC" "$CWD" "$SPEC_ID" --skip-agents; then
      die "check_spec failed for '$SPEC_ID' — refuse Codex $UNIT (fix Spec or SKIP_SPEC_CHECK=1)"
    fi
  fi
fi

# Completion is decided by turn.completed, so the event stream is not optional for
# units whose success we assert mechanically.
if [[ "$JSON" != "1" && "${SKIP_TURN_CHECK:-0}" != "1" ]]; then
  die "--no-json disables the turn.completed check; dispatch units need it (SKIP_TURN_CHECK=1 to override)"
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
LAST_MSG_FILE="$LOG_DIR/${RUN_ID}.last.md"
if [[ -n "$RUN_ID_FILE" ]]; then
  mkdir -p "$(dirname "$RUN_ID_FILE")"
  printf '%s\n' "$RUN_ID" >"$RUN_ID_FILE"
fi
echo "codex-dispatch: RUN_ID=$RUN_ID" >&2

# Freeze the Oracle text next to the meta. ship.sh replays from this file, because tests.md
# stays writable by the implementer for the whole dispatch: an Oracle it rewrote after the
# fact grades whatever it likes, and the replay would still report red→green. Same parser as
# the payload, so "what the Oracle is" keeps one definition.
ORACLE_FREEZE=""; ORACLE_FREEZE_SHA=""
if [[ "$UNIT" == "build" && -n "$SPEC_ID" && -n "$SLICE_ID" ]]; then
  _pack="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_context_pack.py"
  if [[ -f "$_pack" ]]; then
    _frz="$LOG_DIR/${RUN_ID}.oracles.tsv"
    : >"$_frz"
    _frz_ok=1
    for _sl in $(printf '%s' "$SLICE_ID" | tr ',' ' '); do
      [[ -n "$_sl" ]] || continue
      if ! python3 "$_pack" --json "$CWD" "$SPEC_ID" "$_sl" 2>/dev/null | python3 -c '
import json, sys
pack = json.load(sys.stdin)
for o in pack.get("oracles", []):
    print("\t".join([o.get("id", ""), o.get("kind", ""), o.get("cmd", "").strip("`").strip()]))
' >>"$_frz"; then
        _frz_ok=0; break
      fi
    done
    if [[ "$_frz_ok" == "1" && -s "$_frz" ]]; then
      # Dedupe by id the way ship.sh does, then sort: the digest must not depend on the
      # order the slices happened to be listed in.
      LC_ALL=C sort -u -t$'\t' -k1,1 "$_frz" -o "$_frz"
      ORACLE_FREEZE="$_frz"
      ORACLE_FREEZE_SHA="$(LC_ALL=C sort "$_frz" | sha256sum | cut -d' ' -f1)"
      echo "codex-dispatch: froze $(wc -l <"$_frz" | tr -d ' ') Oracles -> $_frz" >&2
    else
      rm -f "$_frz"
      echo "codex-dispatch: WARN could not freeze Oracles for $SPEC_ID/$SLICE_ID — ship.sh \
will have to re-read tests.md, which the implementer can edit" >&2
    fi
  fi
fi

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
  [[ -n "$SLICE_ID" ]] && echo "slice=${SLICE_ID%%,*}"
  [[ -n "$SLICE_ID" ]] && echo "slices=$SLICE_ID"
  [[ -n "$DISPATCH_ID" ]] && echo "dispatch_id=$DISPATCH_ID"
  echo "last_message=$LAST_MSG_FILE"
  # HEAD at dispatch time IS the baseline tree: ship.sh needs it to prove each Oracle
  # RED before the implementation exists. Recording it here keeps the operator out of
  # the loop — a remembered SHA is not evidence.
  bsha="$(git -C "$CWD" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$bsha" ]] && echo "base_sha=$bsha"
  [[ -n "$ORACLE_FREEZE" ]] && echo "oracles_file=$ORACLE_FREEZE"
  [[ -n "$ORACLE_FREEZE_SHA" ]] && echo "oracles_sha256=$ORACLE_FREEZE_SHA"
  # Written before the run so a killed dispatch leaves an unambiguous marker instead
  # of a missing field: 9 of 75 real dispatches had no exit_status at all and the
  # conductor could not tell success from a crash.
  echo "run_state=started"
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
  -c 'approval_policy="never"'
  --skip-git-repo-check
)
# A profile only wins if we do NOT also pass -m/-c effort: CLI flags outrank profiles.
if [[ -n "$PROFILE" ]]; then
  CMD+=(-p "$PROFILE")
  if [[ -n "$MODEL_EXPLICIT" ]]; then CMD+=(-m "$MODEL"); fi
  if [[ -n "$EFFORT_EXPLICIT" ]]; then CMD+=(-c "model_reasoning_effort=\"${EFFORT}\""); fi
else
  CMD+=(-m "$MODEL" -c "model_reasoning_effort=\"${EFFORT}\"")
fi

if [[ "$JSON" == "1" ]]; then
  CMD+=(--json)
fi
CMD+=(--output-last-message "$LAST_MSG_FILE")

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
  echo "run_state=finished"
} >>"$META_FILE"

# Quota exhaustion is not an implementation failure. 6 of 75 real dispatches died
# here and were indistinguishable from "Codex could not do the work".
# Scoped to error / turn.failed events only. Scanning the whole jsonl misfires the
# moment a run reads a file that merely mentions quotas — including this script.
QUOTA_LINES=""
if [[ -f "$LOG_FILE" ]]; then
  QUOTA_LINES="$(grep -E '"type"[[:space:]]*:[[:space:]]*"(error|turn\.failed)"' "$LOG_FILE" \
    | grep -iE 'hit your usage limit|usage limit reached' || true)"
fi
# The real CLI may report the quota only on stderr, with no error event in the jsonl.
if [[ -z "$QUOTA_LINES" && $STATUS -ne 0 && -f "$STDERR_FILE" ]]; then
  QUOTA_LINES="$(grep -iE 'hit your usage limit|usage limit reached' "$STDERR_FILE" || true)"
fi
if [[ -n "$QUOTA_LINES" ]]; then
  RETRY="$(printf '%s' "$QUOTA_LINES" | grep -oiE 'try again at [^"\\]{0,40}' | head -1)"
  {
    echo "failure_class=quota"
    [[ -n "$RETRY" ]] && echo "quota_retry_hint=$RETRY"
  } >>"$META_FILE"
  echo "codex-dispatch: QUOTA EXHAUSTED — subscription window, not an implementation failure." >&2
  [[ -n "$RETRY" ]] && echo "codex-dispatch: $RETRY" >&2
  echo "codex-dispatch: lower the tier (--model gpt-5.6-terra|luna) or wait; meta=$META_FILE" >&2
  exit 75   # EX_TEMPFAIL: retryable, distinct from a real dispatch failure
fi

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

DETECT_COMPACT="$PLUGIN_ROOT/skills/dispatch-codex/scripts/detect_compact.py"
# Completion signal is turn.completed — never the process exit code.
# Applies to every unit: a Plan that died mid-write is a failure too.
if [[ "$JSON" == "1" ]] \
  && [[ -f "$DETECT_COMPACT" ]] && [[ -f "$LOG_FILE" ]]; then
  set +e
  inspect_json="$(python3 "$DETECT_COMPACT" --require-turn "$LOG_FILE")"
  inspect_rc=$?
  set -e
  printf '%s\n' "$inspect_json"
  acts="$(printf '%s' "$inspect_json" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("actions", 0))
except Exception: print(0)' 2>/dev/null || echo 0)"
  echo "actions=$acts" >>"$META_FILE"
  # Detection, not prediction: 720 real sessions put the compaction cliff at 200 agent
  # actions (<=50 -> 3%, 51-200 -> 64%, 200+ -> 100%). 150 is the shoulder to stop at.
  if [[ "$acts" =~ ^[0-9]+$ ]] && [[ "$acts" -ge 150 ]]; then
    echo "codex-dispatch: WARN this unit took $acts agent actions; the compaction cliff is 200." >&2
    echo "  Split the next dispatch unit — do not push a bigger one through." >&2
    echo "action_budget=over-shoulder" >>"$META_FILE"
  fi
  if [[ "$inspect_rc" -ne 0 ]]; then
    echo "codex-dispatch: Codex jsonl did not finish cleanly (need turn.completed, no compact event) log=$LOG_FILE" >&2
    echo "exit_status=2" >>"$META_FILE"
    echo "turn_incomplete_or_compact=1" >>"$META_FILE"
    exit 2
  fi
fi

echo "codex-dispatch: ok; meta=$META_FILE" >&2
if [[ "$UNIT" == "build" ]]; then
  echo "codex-dispatch: NEXT — replay the frozen Oracles on this dispatch's baseline" >&2
  echo "codex-dispatch: then: bash skills/dispatch-codex/scripts/ship.sh --host $CWD${SPEC_ID:+ --spec $SPEC_ID}${SLICE_ID:+ --slice $SLICE_ID} --from-meta $META_FILE" >&2
fi
exit 0
