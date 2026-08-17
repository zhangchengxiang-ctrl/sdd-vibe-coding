#!/usr/bin/env bash
# ship.sh — replay the frozen Oracles. Each one must be RED on the baseline tree first.
#
# Why the baseline half exists: an archived Spec's P0 Oracle was replayed here and exits 1
# on the shipped tree — nobody had ever run it. Another Spec's Oracle was `true`. Neither
# gate noticed, because "the command passes" says nothing unless the same command fails
# with the feature removed. A command that is green on both trees measures nothing.
#
# Usage:
#   bash ship.sh --host DIR --spec ID [--slice S1] [--base SHA | --from-meta FILE]
#                [--phase baseline|verify|both] [--evidence FILE] [--resume]
#                [--link "node_modules .venv"] [--timeout SEC] [--dry-run]
#
# Exit 0 every machine Oracle red-then-green · 1 a replay verdict failed · 2 refused
set -uo pipefail

HOST=""; SPEC=""; SLICE=""; BASE=""; META=""; PHASE="both"; EVIDENCE=""
RESUME=0; DRY=0; TIMEOUT_SEC="${SHIP_TIMEOUT_SEC:-900}"
LINKS="${SHIP_LINK:-node_modules}"

die() { echo "ship: $*" >&2; exit 2; }
usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --spec) SPEC="${2:-}"; shift 2 ;;
    --slice) SLICE="${2:-}"; shift 2 ;;
    --base) BASE="${2:-}"; shift 2 ;;
    --from-meta) META="${2:-}"; shift 2 ;;
    --phase) PHASE="${2:-}"; shift 2 ;;
    --evidence) EVIDENCE="${2:-}"; shift 2 ;;
    --link) LINKS="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT_SEC="${2:-}"; shift 2 ;;
    --resume) RESUME=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option $1 (try --help)" ;;
  esac
done

[[ -n "$HOST" && -n "$SPEC" ]] || { usage >&2; die "--host and --spec are required"; }
[[ -d "$HOST" ]] || die "not a directory: $HOST"
HOST="$(cd "$HOST" && pwd)"
case "$PHASE" in baseline|verify|both) ;; *) die "--phase must be baseline|verify|both" ;; esac
[[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]] || die "--timeout must be an integer"
command -v timeout >/dev/null 2>&1 || die "GNU timeout missing — a replay cannot be bounded"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACK="$HERE/build_context_pack.py"
[[ -f "$PACK" ]] || die "missing $PACK — cannot read the frozen Oracles"

if [[ -n "$META" ]]; then
  [[ -f "$META" ]] || die "no such meta file: $META"
  from_meta="$(sed -n 's/^base_sha=//p' "$META" | head -1)"
  [[ -n "$from_meta" ]] || die "$META has no base_sha= (dispatched before ship.sh existed?)"
  [[ -z "$BASE" ]] && BASE="$from_meta"
fi

# The Oracle list comes from the dispatch throat, not a second parser: the definition of
# "executable" must exist once. That call already exits 2 on an invalid or under-covered
# Oracle set, so a refusal here is the same refusal the dispatch got.
PACK_ERR="$(mktemp)"; trap 'rm -f "$PACK_ERR"' EXIT
# No --slice means the whole Spec: closing needs every P0 Oracle, not one unit's. The
# pack is per-slice by design, so iterate its own --list rather than teaching a second
# place how to read plan.md.
if [[ -n "$SLICE" ]]; then
  TARGET_SLICES=("$SLICE")
else
  mapfile -t TARGET_SLICES < <(python3 "$PACK" --list "$HOST" "$SPEC" 2>"$PACK_ERR")
  [[ "${#TARGET_SLICES[@]}" -gt 0 ]] || { cat "$PACK_ERR" >&2
    die "no slices in $SPEC/plan.md — pass --slice, or fix the slice table"; }
fi

ORACLES=(); SLICE_LABEL=""
for sl in "${TARGET_SLICES[@]}"; do
  [[ -n "$sl" ]] || continue
  # stdout only: folding stderr in would corrupt the JSON with any warning the pack prints.
  pj="$(python3 "$PACK" --json "$HOST" "$SPEC" "$sl" 2>"$PACK_ERR")" || {
    cat "$PACK_ERR" >&2
    if grep -q 'REFUSED' "$PACK_ERR"; then
      die "the dispatch throat refuses $SPEC/$sl — fix tests.md, not this run"
    fi
    die "build_context_pack failed for $SPEC/$sl (see above) — this is not an Oracle verdict"
  }
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    oid="${line%%$'\t'*}"
    dup=0
    for have in "${ORACLES[@]}"; do [[ "${have%%$'\t'*}" == "$oid" ]] && dup=1 && break; done
    [[ "$dup" == "1" ]] || ORACLES+=("$line")
  done < <(printf '%s' "$pj" | python3 -c '
import json, sys
pack = json.load(sys.stdin)
for o in pack.get("oracles", []):
    print("\t".join([o.get("id", ""), o.get("kind", ""), o.get("cmd", "").strip("`").strip()]))
')
  if [[ -z "$SLICE_LABEL" ]]; then
    SLICE_LABEL="$(printf '%s' "$pj" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("dispatch_id",""))')"
  fi
done
[[ -n "$SLICE" ]] || SLICE_LABEL="all"
[[ "${#ORACLES[@]}" -gt 0 ]] || die "no Oracles for $SPEC${SLICE:+ / $SLICE} — nothing to replay"

MACHINE=(); HUMAN=()
for row in "${ORACLES[@]}"; do
  IFS=$'\t' read -r oid okind ocmd <<<"$row"
  case "$okind" in
    machine) MACHINE+=("$oid"$'\t'"$ocmd") ;;
    human)   HUMAN+=("$oid") ;;
    *) die "oracle $oid is $okind — the throat should have refused this already" ;;
  esac
done
[[ "${#MACHINE[@]}" -gt 0 ]] || die "every Oracle for $SPEC${SLICE:+ / $SLICE} is 人工 — \
a human must judge them; there is nothing for the runner to replay"

git -C "$HOST" rev-parse --git-dir >/dev/null 2>&1 || die "$HOST is not a git repo — \
without a baseline tree, a green command proves nothing"
HEAD_SHA="$(git -C "$HOST" rev-parse HEAD)"
if [[ "$PHASE" != "verify" ]]; then
  [[ -n "$BASE" ]] || die "--base SHA (or --from-meta FILE) is required for the baseline \
phase — guessing which tree predates the change would fake the red half"
  BASE="$(git -C "$HOST" rev-parse --verify "${BASE}^{commit}" 2>/dev/null)" \
    || die "not a commit in $HOST: $BASE"
fi

EVIDENCE="${EVIDENCE:-$HOST/.sdd-evidence/${SPEC}${SLICE_LABEL:+-$SLICE_LABEL}.jsonl}"
mkdir -p "$(dirname "$EVIDENCE")" || die "cannot create evidence dir for $EVIDENCE"
LOG_ROOT="$(dirname "$EVIDENCE")/logs"; mkdir -p "$LOG_ROOT"

# --- environment-vs-assertion ------------------------------------------------
# RED for the wrong reason is not evidence. A missing dependency fails every command in a
# fresh worktree, which would satisfy the baseline requirement without measuring anything.
ENV_FAIL='Cannot find module|MODULE_NOT_FOUND|ModuleNotFoundError|No module named'
ENV_FAIL="$ENV_FAIL|command not found|executable file not found|Cannot find package"
classify_fail() {   # $1 exit, $2 log path → red | inconclusive
  local rc="$1" log="$2"
  if [[ "$rc" -eq 126 || "$rc" -eq 127 ]]; then echo inconclusive; return; fi
  if grep -qE "$ENV_FAIL" "$log" 2>/dev/null; then echo inconclusive; return; fi
  echo red
}

already() {   # $1 id, $2 phase, $3 tree — resume skips work already witnessed on this tree
  [[ "$RESUME" == "1" && -f "$EVIDENCE" ]] || return 1
  python3 - "$EVIDENCE" "$1" "$2" "$3" <<'PY'
import json, sys
ev, oid, phase, tree = sys.argv[1:5]
for line in open(ev, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        r = json.loads(line)
    except ValueError:
        continue
    if (r.get("id"), r.get("phase"), r.get("tree")) == (oid, phase, tree) \
            and r.get("verdict") in {"red", "green"}:
        sys.exit(0)
sys.exit(1)
PY
}

record() {   # id phase tree cmd exit verdict log
  python3 - "$EVIDENCE" "$SPEC" "$SLICE_LABEL" "$@" <<'PY'
import hashlib, json, os, sys, time
ev, spec, slice_id, oid, phase, tree, cmd, rc, verdict, log = sys.argv[1:11]
sha = ""
if os.path.isfile(log):
    with open(log, "rb") as fh:
        sha = hashlib.sha256(fh.read()).hexdigest()
row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "spec": spec, "slice": slice_id,
       "id": oid, "phase": phase, "tree": tree, "cmd": cmd, "exit": int(rc),
       "verdict": verdict, "stdout_sha256": sha, "log": log}
with open(ev, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(row, ensure_ascii=False) + "\n")
PY
}

# Sets globals LOG and RC. Deliberately not via command substitution: that runs the
# function in a subshell, so the exit code it captured would never reach the caller and
# every replay would read as success.
LOG=""; RC=0
run_one() {   # cwd id phase tree cmd
  local cwd="$1" oid="$2" phase="$3" tree="$4" cmd="$5"
  LOG="$LOG_ROOT/${oid}-${phase}-${tree:0:8}.log"
  if [[ "$DRY" == "1" ]]; then RC=0; return 0; fi
  ( cd "$cwd" && timeout --signal=TERM --kill-after=30s "${TIMEOUT_SEC}s" \
      bash -c "$cmd" ) >"$LOG" 2>&1
  RC=$?
}

FAILED=0; PASSED=0
declare -A BASE_VERDICT=()

# --- baseline: every machine Oracle must be RED, for the right reason -------------
if [[ "$PHASE" != "verify" ]]; then
  WT="${TMPDIR:-/tmp}/sdd-ship-base-$(printf '%s' "$HOST" | cksum | cut -d' ' -f1)-${BASE:0:8}"
  if [[ -d "$WT" ]]; then
    # Reuse only a clean tree, ignoring the dep symlinks this script made itself; a dirty
    # baseline is not the baseline.
    dirty="$(git -C "$WT" status --porcelain 2>/dev/null \
      | grep -vE "^\?\? ($(printf '%s' "$LINKS" | tr ' ' '|'))/?$" || true)"
    [[ -z "$dirty" ]] || die "stale baseline worktree $WT is dirty; rm -rf it and rerun:
$dirty"
  else
    git -C "$HOST" worktree add --detach "$WT" "$BASE" >/dev/null 2>&1 \
      || die "cannot create baseline worktree at $WT"
  fi
  read -r -a _links <<<"$LINKS"   # split on spaces, never glob
  for l in "${_links[@]}"; do
    [[ -n "$l" && -e "$HOST/$l" && ! -e "$WT/$l" ]] && ln -s "$HOST/$l" "$WT/$l"
  done
  echo "ship: baseline=$BASE worktree=$WT" >&2
  for row in "${MACHINE[@]}"; do
    IFS=$'\t' read -r oid ocmd <<<"$row"
    if already "$oid" baseline "$BASE"; then
      echo "SKIP  $oid baseline (already witnessed on $BASE)" >&2
      BASE_VERDICT[$oid]=red; continue
    fi
    run_one "$WT" "$oid" baseline "$BASE" "$ocmd"; log="$LOG"; rc="$RC"
    if [[ "$DRY" == "1" ]]; then echo "DRY   $oid baseline: $ocmd"; continue; fi
    if [[ "$rc" -eq 0 ]]; then
      verdict=nondiscriminating
      echo "FAIL  $oid baseline GREEN — this command passes with the feature absent, \
so it measures nothing: $ocmd" >&2
    else
      verdict="$(classify_fail "$rc" "$log")"
      if [[ "$verdict" == "inconclusive" ]]; then
        echo "FAIL  $oid baseline red for the wrong reason (exit $rc, missing dependency \
or binary) — link deps with --link or fix the environment; see $log" >&2
      else
        echo "OK    $oid baseline RED (exit $rc)" >&2
      fi
    fi
    BASE_VERDICT[$oid]="$verdict"
    record "$oid" baseline "$BASE" "$ocmd" "$rc" "$verdict" "$log"
    [[ "$verdict" == "red" ]] || FAILED=$((FAILED+1))
  done
fi

# --- verify: the same commands, on the tree that claims to implement them ---------
if [[ "$PHASE" != "baseline" ]]; then
  echo "ship: verify tree=$HEAD_SHA" >&2
  for row in "${MACHINE[@]}"; do
    IFS=$'\t' read -r oid ocmd <<<"$row"
    if [[ "$PHASE" == "both" && "${BASE_VERDICT[$oid]:-}" != "red" ]]; then
      echo "SKIP  $oid verify — its baseline half is ${BASE_VERDICT[$oid]:-missing}; \
a green run here would prove nothing" >&2
      continue
    fi
    if already "$oid" verify "$HEAD_SHA"; then
      echo "SKIP  $oid verify (already witnessed on $HEAD_SHA)" >&2
      PASSED=$((PASSED+1)); continue
    fi
    run_one "$HOST" "$oid" verify "$HEAD_SHA" "$ocmd"; log="$LOG"; rc="$RC"
    if [[ "$DRY" == "1" ]]; then echo "DRY   $oid verify: $ocmd"; continue; fi
    if [[ "$rc" -eq 0 ]]; then
      echo "OK    $oid verify GREEN"; verdict=green; PASSED=$((PASSED+1))
    else
      echo "FAIL  $oid verify exit $rc — see $log" >&2; verdict=failed; FAILED=$((FAILED+1))
    fi
    record "$oid" verify "$HEAD_SHA" "$ocmd" "$rc" "$verdict" "$log"
  done
fi

# 人工 Oracles are owed, not waived: they never counted toward the replay set in the
# dispatch payload either, so they cannot be closed by this script's exit code.
if [[ "${#HUMAN[@]}" -gt 0 ]]; then
  echo "OWED  人工判定 (not replayed, not satisfied by this run): ${HUMAN[*]}" >&2
fi

if [[ "$PHASE" == "verify" ]]; then
  # Green alone is not red-green. Each row carries its phase, so the close gate can
  # require both halves per Oracle; this line makes the shortfall visible here too.
  echo "WARN  --phase verify recorded green without a baseline half — this is NOT \
red-green evidence and must not close a Spec on its own" >&2
fi

echo "--- ship: spec=$SPEC${SLICE_LABEL:+ unit=$SLICE_LABEL} phase=$PHASE \
machine=${#MACHINE[@]} green=$PASSED failed=$FAILED human_owed=${#HUMAN[@]} \
evidence=$EVIDENCE ---"
[[ "$FAILED" -eq 0 ]] || exit 1
exit 0
