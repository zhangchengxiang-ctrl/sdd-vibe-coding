#!/usr/bin/env bash
# Oracle migration worklist: which P0 Oracles a runner still cannot execute, and why.
#
# Not a gate — a meter. The gates (check_spec, the dispatch throat, ship.sh) refuse an
# unexecutable Oracle at the moment it matters; this says how much rewriting is left, so the
# bill is visible instead of being discovered one dispatch at a time.
#
# Measured when the gates landed: 82% of 124 in-flight T-ids and 85% of 564 archived ones were
# refused, and 93% of the refusals were unsalvageable by any parser (69% backticked spans that
# are not commands — SQL fragments, bare paths — and 24% pure prose). Loosening the判据 to
# "take the single runnable backticked span" would have rescued 3.5%. So this is real work,
# not a parser artifact, and it is listed per Spec because that is how it gets done.
#
# Usage:
#   bash scripts/oracle-migration.sh --cwd HOST [--archived] [--csv]
#   make oracle-migration HOST=~/code/agentdeck
set -uo pipefail
CWD="."; ARCHIVED=0; CSV=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="${2:-}"; shift 2 ;;
    --archived) ARCHIVED=1; shift ;;
    --csv) CSV=1; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "oracle-migration: unknown option $1" >&2; exit 2 ;;
  esac
done
[[ -d "$CWD" ]] || { echo "oracle-migration: not a directory: $CWD" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$CWD" "$ROOT" "$ARCHIVED" "$CSV" <<'MIG_PY'
import importlib.util, sys
from pathlib import Path

host, root, archived, csv_out = Path(sys.argv[1]).resolve(), Path(sys.argv[2]), sys.argv[3] == "1", sys.argv[4] == "1"
spec = importlib.util.spec_from_file_location("cs", root / "skills/spec/scripts/check_spec.py")
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)

roots = [p for p in host.glob("**/specs") if p.is_dir()]
spec_dirs = []
for r in roots:
    for d in sorted(r.iterdir()):
        if d.is_dir() and d.name != "_template" and (d / "contract.md").is_file():
            spec_dirs.append(d)
        if archived and d.is_dir() and d.name == "archive":
            spec_dirs += [a for a in sorted(d.iterdir()) if (a / "contract.md").is_file()]

def why(cmd: str) -> str:
    bare = (cmd or "").strip().strip("`").strip()
    if not bare:
        return "no 命令 line"
    if bare.lower() in cs.HUMAN_ORACLE:
        return ""
    if cs.NOOP_CMD.match(bare):
        return "no-op"
    if not cs.RUNNABLE_HEAD.match(cs.LEADING_ENV.sub("", bare)):
        return "not executable"
    return ""

rows, totals = [], {"specs": 0, "p0": 0, "todo": 0}
for sd in spec_dirs:
    contract = (sd / "contract.md").read_text(encoding="utf-8", errors="replace")
    tests = (sd / "tests.md").read_text(encoding="utf-8", errors="replace") if (sd / "tests.md").is_file() else ""
    _, req = cs.parse_md_table_after(contract, "Requirements")
    bodies = cs.extract_test_bodies(tests)
    totals["specs"] += 1
    seen = set()
    for r in req:
        if not cs.is_p0(r):
            continue
        import re
        for tid in re.findall(r"T-\d+", cs.row_tests(r)):
            if tid in seen:
                continue
            seen.add(tid)
            totals["p0"] += 1
            body = bodies.get(tid)
            if body is None:
                rows.append((sd.name, tid, "no ## body", ""))
                totals["todo"] += 1
                continue
            cmd = cs.automation_command(body) or ""
            reason = why(cmd)
            if reason:
                rows.append((sd.name, tid, reason, cmd.strip()[:90]))
                totals["todo"] += 1

if csv_out:
    print("spec,t_id,reason,current_command")
    for s, t, why_, cmd in rows:
        print(f'"{s}","{t}","{why_}","{cmd.replace(chr(34), chr(39))}"')
else:
    last = None
    for s, t, why_, cmd in rows:
        if s != last:
            print(f"\n## {s}")
            last = s
        print(f"  {t:8} {why_:16} {cmd or '(none)'}")
    print(f"\n== oracle-migration host={host.name} specs={totals['specs']} "
          f"p0_oracles={totals['p0']} need_rewrite={totals['todo']} "
          f"({0 if not totals['p0'] else round(100 * totals['todo'] / totals['p0'])}%) ==")
MIG_PY
