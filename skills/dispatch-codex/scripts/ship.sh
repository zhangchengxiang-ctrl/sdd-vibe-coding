#!/usr/bin/env bash
# ship.sh — replay the frozen Oracles. Each one must be RED on the baseline tree first.
#
# Why the baseline half exists: an archived Spec's P0 Oracle was replayed here and exits 1
# on the shipped tree — nobody had ever run it. Another Spec's Oracle was `true`. Neither
# gate noticed, because "the command passes" says nothing unless the same command fails
# with the feature removed. A command that is green on both trees measures nothing.
#
# Usage:
#   bash ship.sh --host DIR --spec ID [--slice S1] --from-meta FILE
#                [--phase baseline|verify|both] [--evidence FILE] [--resume]
#                [--link "node_modules .venv"] [--timeout SEC] [--dry-run]
#
# Custody, and its limit: the baseline SHA and the Oracle text both come from the dispatch
# meta, not from the tree being judged — the implementer can edit tests.md, and an Oracle it
# rewrote grades nothing. But .sdd-evidence lives in that same writable tree, so a row is a
# RECORD, not a credential: --resume trusts rows only as far as re-hashing their log, and a
# close gate must replay fresh rather than read this file. SHIP_ALLOW_MANUAL_BASE=1 permits
# --base without a meta and marks every row base_provenance=manual-unverified.
#
# Exit 0 every machine Oracle red-then-green · 1 a replay verdict failed · 2 refused
set -uo pipefail

# Oracles run inside the reusable baseline worktree; Python bytecode written there would make it look
# dirty on the next run ("stale baseline worktree ... is dirty") and abort the replay.
export PYTHONDONTWRITEBYTECODE=1

HOST=""; SPEC=""; SLICE=""; BASE=""; META=""; PHASE="both"; EVIDENCE=""
RESUME=0; DRY=0; TIMEOUT_SEC="${SHIP_TIMEOUT_SEC:-900}"
# `:-` here would make SHIP_LINK= mean "use the default", so an operator who switched
# linking off to dodge a workspace escape would silently keep it on.
LINKS="${SHIP_LINK-node_modules}"
BASE_PROV=""; FREEZE=""; FREEZE_SHA=""; ORACLE_SHA=""

# Alternation for "untracked entries this script created itself". An empty --link would
# otherwise build the regex `^\?\? ()/?$`, which matches nothing useful and errors on some greps.
links_re() {
  local re
  re="$(printf '%s' "$LINKS" | tr -s ' \t' '|' | sed 's/^|//; s/|$//')"
  printf '%s' "${re:-__no_links__}"
}

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

# The baseline must be the dispatcher's, not the judged party's. A meta is a text file, so
# an arbitrary path is something the implementer can author: require it to sit in a dispatch
# log dir, and refuse a --base that contradicts it. Choosing a baseline that already contains
# the feature makes red→green a formality that measures nothing.
if [[ -n "$META" ]]; then
  [[ -f "$META" ]] || die "no such meta file: $META"
  META_ABS="$(cd "$(dirname "$META")" && pwd)/$(basename "$META")"
  case "$META_ABS" in
    */.codex-dispatch-logs/*) ;;
    *) die "--from-meta must live in a .codex-dispatch-logs dir (got $META_ABS) — a meta \
anywhere else is a file the implementer can write" ;;
  esac
  from_meta="$(sed -n 's/^base_sha=//p' "$META" | head -1)"
  [[ -n "$from_meta" ]] || die "$META has no base_sha= (dispatched before ship.sh existed?)"
  [[ -z "$BASE" || "$BASE" == "$from_meta" ]] || die "--base $BASE contradicts \
base_sha=$from_meta in $META — the dispatcher's baseline wins; drop --base"
  BASE="$from_meta"; BASE_PROV="dispatch-meta"
  FREEZE="$(sed -n 's/^oracles_file=//p' "$META" | head -1)"
  FREEZE_SHA="$(sed -n 's/^oracles_sha256=//p' "$META" | head -1)"
elif [[ -n "$BASE" ]]; then
  [[ "${SHIP_ALLOW_MANUAL_BASE:-0}" == "1" ]] || die "--base without --from-meta lets the \
judged party pick its own baseline; pass --from-meta <dispatch meta>, or set \
SHIP_ALLOW_MANUAL_BASE=1 to record it as unverified"
  BASE_PROV="manual-unverified"
fi

# The Oracle list comes from the dispatch throat, not a second parser: the definition of
# "executable" must exist once. That call already exits 2 on an invalid or under-covered
# Oracle set, so a refusal here is the same refusal the dispatch got.
PACK_ERR="$(mktemp)"; trap 'rm -f "$PACK_ERR"' EXIT
# One --slice is a dispatch unit. No --slice is the whole Spec, and that set comes from the
# P0 Requirements mapping rather than plan.md: a slice table is a work breakdown, so a P0
# T-id that no slice happens to name would never be replayed and the close would pass
# without it. Either way the Oracle list comes from the dispatch throat, not a second
# parser — the definition of "executable" must exist once.
if [[ -n "$SLICE" ]]; then
  PACK_ARGS=(--json "$HOST" "$SPEC" "$SLICE")
else
  PACK_ARGS=(--oracles-all "$HOST" "$SPEC")
fi
# stdout only: folding stderr in would corrupt the JSON with any warning the pack prints.
pj="$(python3 "$PACK" "${PACK_ARGS[@]}" 2>"$PACK_ERR")" || {
  cat "$PACK_ERR" >&2
  if grep -q 'REFUSED' "$PACK_ERR"; then
    die "the dispatch throat refuses $SPEC${SLICE:+ / $SLICE} — fix tests.md, not this run"
  fi
  die "build_context_pack failed for $SPEC${SLICE:+ / $SLICE} (see above) — this is not an \
Oracle verdict"
}
# The pack's WARNs name P0 requirements nothing replays. Swallowing them here would make an
# incomplete replay look complete.
grep -q 'WARN' "$PACK_ERR" 2>/dev/null && sed 's/^/ship: /' "$PACK_ERR" >&2

ORACLES=(); SLICE_LABEL=""
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
SLICE_LABEL="$(printf '%s' "$pj" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("dispatch_id",""))')"
[[ -n "$SLICE" ]] || SLICE_LABEL="all"
[[ "${#ORACLES[@]}" -gt 0 ]] || die "no Oracles for $SPEC${SLICE:+ / $SLICE} — nothing to replay"

# The judge may not be rewritten by the party it judges. Everything above re-parsed the
# CURRENT tests.md, which the implementer can edit after dispatch: swapping in `bash -c
# '[ -d .git ]'` is RED in a detached worktree (.git is a file there) and GREEN in the host,
# so red→green passes without the feature being touched.
#
# Compared PER T-ID, not as one digest of the whole set. A digest comparison made a normal
# multi-slice Spec impossible to close: each dispatch freezes only its own slice's Oracles, so
# closing the whole Spec compared {T-001} against {T-001,T-002} and called it drift when
# nothing had drifted. Every frozen row this Spec has must still match; a T-id nobody froze is
# reported, because "never dispatched" is not the same as "verified unchanged".
declare -A FROZEN=()
freeze_files=()
[[ -n "$FREEZE" ]] && freeze_files+=("$FREEZE")
if [[ -z "$SLICE" ]]; then
  # Whole-Spec replay: the frozen record is the union of every dispatch this Spec had.
  while IFS= read -r m; do
    [[ -n "$m" ]] || continue
    grep -qxF "spec=$SPEC" "$m" 2>/dev/null || continue
    f="$(sed -n 's/^oracles_file=//p' "$m" | head -1)"
    [[ -n "$f" && -f "$f" ]] || continue
    freeze_files+=("$f")
  done < <(ls -tr "$HOST/.codex-dispatch-logs"/*.meta.txt 2>/dev/null)
fi
declare -A FROZEN_SRC=()
freeze_conflict=()
for f in ${freeze_files[@]+"${freeze_files[@]}"}; do
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    fid="${line%%$'\t'*}"
    if [[ -n "${FROZEN[$fid]:-}" && "${FROZEN[$fid]}" != "$line" ]]; then
      # Last-write-wins here would let a second dispatch (or a hand-written meta) replace the
      # judge the first one was held to, which is the drift this whole mechanism exists to catch.
      echo "ship: $fid frozen differently by ${FROZEN_SRC[$fid]}: ${FROZEN[$fid]}" >&2
      echo "ship: $fid frozen differently by $(basename "$f"): $line" >&2
      freeze_conflict+=("$fid")
      continue
    fi
    FROZEN["$fid"]="$line"
    FROZEN_SRC["$fid"]="$(basename "$f")"
  done <"$f"
done
if [[ "${#freeze_conflict[@]}" -gt 0 ]]; then
  die "two dispatches froze ${freeze_conflict[*]} differently — the Oracle changed between \
them. Decide which judge stands and re-dispatch; do not close across both."
fi

if [[ -n "$FREEZE" && -n "${FREEZE_SHA:-}" ]]; then
  froze_sha="$(LC_ALL=C sort "$FREEZE" | sha256sum | cut -d' ' -f1)"
  [[ "$FREEZE_SHA" == "$froze_sha" ]] || die "oracles_file $FREEZE does not match \
oracles_sha256 in $META — it was edited after dispatch"
fi
[[ -z "$FREEZE" || -f "$FREEZE" ]] || die "meta names oracles_file=$FREEZE but it is missing \
— the frozen Oracle set is gone; re-dispatch instead of trusting the current tests.md"

drifted=(); unfrozen=()
for i in "${!ORACLES[@]}"; do
  oid="${ORACLES[$i]%%$'\t'*}"
  if [[ -z "${FROZEN[$oid]:-}" ]]; then
    unfrozen+=("$oid")
    continue
  fi
  if [[ "${FROZEN[$oid]}" != "${ORACLES[$i]}" ]]; then
    drifted+=("$oid")
    echo "ship: $oid frozen at dispatch: ${FROZEN[$oid]}" >&2
    echo "ship: $oid tests.md now:      ${ORACLES[$i]}" >&2
  fi
  ORACLES[$i]="${FROZEN[$oid]}"   # replay the frozen text, not the current one
done
if [[ "${#drifted[@]}" -gt 0 ]]; then
  die "oracle drift on ${drifted[*]} — tests.md changed after the dispatch that froze them. \
Re-dispatch to refreeze; a replay against a rewritten judge proves nothing"
fi
if [[ "${#unfrozen[@]}" -gt 0 ]]; then
  echo "ship: WARN no dispatch froze ${unfrozen[*]} — replaying the current tests.md for \
them, which the implementer could have written. Dispatch them, or judge them by hand." >&2
fi
if [[ -z "$SLICE" ]]; then
  # Only meaningful for a whole-Spec replay: per-slice, the other slices' frozen ids are
  # legitimately absent from this unit.
  vanished=()
  for fid in "${!FROZEN[@]}"; do
    found=0
    for row in "${ORACLES[@]}"; do [[ "${row%%$'\t'*}" == "$fid" ]] && found=1 && break; done
    [[ "$found" == "1" ]] || vanished+=("$fid")
  done
  if [[ "${#vanished[@]}" -gt 0 ]]; then
    die "${vanished[*]} was frozen by a dispatch but is no longer a P0 Oracle of this Spec — \
an obligation cannot be closed by deleting it. Restore the mapping, or archive the Spec."
  fi
fi
ORACLE_SHA="$(printf '%s\n' "${ORACLES[@]}" | LC_ALL=C sort | sha256sum | cut -d' ' -f1)"

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
# Verify executes the working tree, not the commit. Recording only HEAD lets evidence name a
# committed tree that was never tested: leave HEAD at the baseline, edit the file without
# committing, and both rows carry the same SHA while measuring different trees.
VERIFY_TREE="$HEAD_SHA"; DIRTY=0
# .sdd-evidence/ is this script's own output; counting it would stamp every run "+dirty".
_st="$(git -C "$HOST" status --porcelain 2>/dev/null | grep -vE "^\?\? (($(links_re))|\.sdd-evidence)/?$" || true)"
if [[ -n "$_st" ]]; then
  DIRTY=1
  _dsha="$( { git -C "$HOST" diff HEAD; printf '%s\n' "$_st"; } | sha256sum | cut -d' ' -f1)"
  VERIFY_TREE="${HEAD_SHA}+dirty.${_dsha:0:12}"
  echo "ship: verify tree is DIRTY — evidence will name $VERIFY_TREE, not a bare commit" >&2
fi
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
  # 124 is GNU timeout, 125 is timeout itself failing, >128 is death by signal. None of them
  # is a verdict, and counting them RED would satisfy the baseline half with a command that
  # merely hangs there and exits 0 in the host.
  if [[ "$rc" -eq 124 || "$rc" -eq 125 || "$rc" -gt 128 ]]; then echo inconclusive; return; fi
  if grep -qE "$ENV_FAIL" "$log" 2>/dev/null; then echo inconclusive; return; fi
  echo red
}

# The judge must predate the work. An Oracle naming a test file that does not exist on the
# baseline tree is red only because there is no test yet — so the implementer supplies both
# the code and the thing that grades it, and red→green is satisfied by its own fixture.
# That is the maker ≠ grader rule, and it is the one this whole script rests on.
# Measured on 108 real machine Oracles: 59 path tokens resolve, 11 do not — every one of
# those 11 in an already-closed Spec. Only judge-shaped tokens are checked (test/spec
# files, .sh/.py runners), so an output path like `--out dist/report.json` is not one.
missing_judge() {   # $1 tree root, $2 command → prints the first missing path, if any
  local root="$1" cmd="$2" tok base
  for tok in $(printf '%s' "$cmd" | tr -s ' \t"'"'" '\n\n\n\n'); do
    tok="${tok%%::*}"
    case "$tok" in
      -*|*'*'*|*'?'*|*'$'*) continue ;;
      */*) ;;
      *) continue ;;
    esac
    base="${tok##*/}"
    case "$base" in
      *.*) ;;
      *) continue ;;
    esac
    case "$base" in
      *test*|*spec*|*.sh|*.py) ;;
      *) continue ;;
    esac
    # An absolute path points outside the tree (an isolated runner, a system tool): the
    # implementer cannot create it there, so test the path itself. Joining it to $root
    # produced "<root>//tmp/x", which never exists, and flagged every external judge.
    if [[ "$tok" == /* ]]; then
      [[ -e "$tok" ]] || { printf '%s' "$tok"; return 0; }
    elif [[ ! -e "$root/$tok" ]]; then
      printf '%s' "$tok"; return 0
    fi
  done
  return 1
}

already() {   # $1 id, $2 phase, $3 tree — resume skips work already witnessed on this tree
  [[ "$RESUME" == "1" && -f "$EVIDENCE" ]] || return 1
  python3 - "$EVIDENCE" "$1" "$2" "$3" "$ORACLE_SHA" <<'PY'
import hashlib, json, os, sys
ev, oid, phase, tree, osha = sys.argv[1:6]
for line in open(ev, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        r = json.loads(line)
    except ValueError:
        continue
    if (r.get("id"), r.get("phase"), r.get("tree")) != (oid, phase, tree):
        continue
    if r.get("verdict") not in {"red", "green"} or r.get("oracle_sha256") != osha:
        continue
    # Appending {"id":…,"verdict":"red"} by hand used to skip the execution outright. A row
    # now only counts if the log it names is on disk and still hashes to what it claims.
    # This raises the cost of a forgery; it does not make this file a credential.
    log, want = r.get("log") or "", r.get("stdout_sha256") or ""
    if not (want and os.path.isfile(log)):
        continue
    with open(log, "rb") as fh:
        if hashlib.sha256(fh.read()).hexdigest() != want:
            continue
    sys.exit(0)
sys.exit(1)
PY
}

record() {   # id phase tree cmd exit verdict log
  python3 - "$EVIDENCE" "$SPEC" "$SLICE_LABEL" "$ORACLE_SHA" "$BASE_PROV" "$@" <<'PY'
import hashlib, json, os, sys, time
ev, spec, slice_id, osha, bprov, oid, phase, tree, cmd, rc, verdict, log = sys.argv[1:13]
sha = ""
if os.path.isfile(log):
    with open(log, "rb") as fh:
        sha = hashlib.sha256(fh.read()).hexdigest()
row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "spec": spec, "slice": slice_id,
       "id": oid, "phase": phase, "tree": tree, "cmd": cmd, "exit": int(rc),
       "verdict": verdict, "stdout_sha256": sha, "log": log,
       "oracle_sha256": osha, "base_provenance": bprov, "witness": "ran"}
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
  # Baseline trees are a cache keyed by (host path, base SHA): reused across runs and never
  # removed on exit, so they pile up in TMPDIR (tmpfs on the dev host). Drop trees untouched
  # for SHIP_WT_TTL_MIN (default a day) before reusing. No live replay runs that long, so this
  # cannot race another dispatch, and a dirty tree left by an interrupted run is exactly what
  # the reuse guard below would abort on.
  if [[ "$DRY" != "1" ]]; then
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'sdd-ship-base-*' \
      -mmin +"${SHIP_WT_TTL_MIN:-1440}" -exec rm -rf {} + 2>/dev/null
    git -C "$HOST" worktree prune >/dev/null 2>&1 || true
  fi
  WT="${TMPDIR:-/tmp}/sdd-ship-base-$(printf '%s' "$HOST" | cksum | cut -d' ' -f1)-${BASE:0:8}"
  if [[ -d "$WT" ]]; then
    # Reuse only a clean tree, ignoring the dep symlinks this script made itself; a dirty
    # baseline is not the baseline.
    # A dep symlink this script made is not dirt. Judge that by what the entry IS — an
    # untracked symlink pointing at the host's copy of the same name — rather than by the
    # current --link list, or a link left by an earlier run reads as a dirty baseline the
    # moment the operator switches linking off.
    dirty=""
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      # Leftover bytecode from an earlier oracle run is not a change to the baseline.
      [[ "$line" == *__pycache__* ]] && continue
      if [[ "$line" == '??'* ]]; then
        entry="${line#\?\? }"; entry="${entry%/}"
        if [[ -L "$WT/$entry" && "$(readlink "$WT/$entry")" == "$HOST/$entry" ]]; then
          continue
        fi
      fi
      dirty+="$line"$'\n'
    done < <(git -C "$WT" status --porcelain 2>/dev/null || true)
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
  # Linking deps keeps RED from meaning "no node_modules". But a workspace package inside
  # them (node_modules/@app/x -> ../../packages/x) points back at the working tree, so the
  # baseline would execute exactly the post-change source it is supposed to lack.
  for l in "${_links[@]}"; do
    [[ -n "$l" && -d "$HOST/$l" ]] || continue
    while IFS= read -r esc; do
      [[ -n "$esc" ]] || continue
      tgt="$(readlink -f "$esc" 2>/dev/null || true)"
      [[ -n "$tgt" ]] || continue
      case "$tgt" in
        "$HOST/$l"|"$HOST/$l"/*) continue ;;
        "$HOST"|"$HOST"/*)
          die "linked dep $l escapes into the working tree: ${esc#"$HOST/"} -> \
${tgt#"$HOST/"}. The baseline would run post-change code, so its RED measures nothing. \
Drop $l from --link, or install a pristine dep tree for the baseline." ;;
      esac
    done < <(find "$HOST/$l" -maxdepth 3 -type l 2>/dev/null)
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
      if mj="$(missing_judge "$WT" "$ocmd")"; then
        verdict=inconclusive
        echo "FAIL  $oid baseline red only because its judge does not exist yet: $mj is \
absent on $BASE — the implementer would write both the code and the test that grades it \
(maker ≠ grader). Freeze the Oracle against a test that predates the work." >&2
      elif [[ "$verdict" == "inconclusive" ]]; then
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
  echo "ship: verify tree=$VERIFY_TREE" >&2
  for row in "${MACHINE[@]}"; do
    IFS=$'\t' read -r oid ocmd <<<"$row"
    if [[ "$PHASE" == "both" && "${BASE_VERDICT[$oid]:-}" != "red" ]]; then
      echo "SKIP  $oid verify — its baseline half is ${BASE_VERDICT[$oid]:-missing}; \
a green run here would prove nothing" >&2
      continue
    fi
    if already "$oid" verify "$VERIFY_TREE"; then
      echo "SKIP  $oid verify (already witnessed on $VERIFY_TREE)" >&2
      PASSED=$((PASSED+1)); continue
    fi
    run_one "$HOST" "$oid" verify "$VERIFY_TREE" "$ocmd"; log="$LOG"; rc="$RC"
    if [[ "$DRY" == "1" ]]; then echo "DRY   $oid verify: $ocmd"; continue; fi
    if [[ "$rc" -eq 0 ]]; then
      echo "OK    $oid verify GREEN"; verdict=green; PASSED=$((PASSED+1))
    else
      echo "FAIL  $oid verify exit $rc — see $log" >&2; verdict=failed; FAILED=$((FAILED+1))
    fi
    record "$oid" verify "$VERIFY_TREE" "$ocmd" "$rc" "$verdict" "$log"
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
