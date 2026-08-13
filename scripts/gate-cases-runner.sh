#!/usr/bin/env bash
# Gate-case catalog + live probes. Replaces adversarial-rot-wave2 inline fixtures.
#
# The catalog (gate-cases.tsv) is the frozen audit record: 91 cases, 40 problems.
# Every problem row must name either a probe that runs here or an open reason,
# so "the 40 are fixed" is a number this script computes, not a claim.
#
# Usage: bash scripts/gate-cases-runner.sh [--baseline-only]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSV="$ROOT/scripts/fixtures/gate-cases.tsv"
[[ -f "$TSV" ]] || { echo "missing $TSV" >&2; exit 2; }

problems=$(awk -F'\t' 'NR>1 && $8=="1"{c++} END{print c+0}' "$TSV")
total=$(awk -F'\t' 'NR>1{c++} END{print c+0}' "$TSV")
echo "== gate-cases catalog total=$total problems=$problems =="
# Append-only register: the 91/40 audit is the floor. Rows are never deleted,
# only resolved (RESOLUTION=probe). Newly measured holes are appended.
[[ "$problems" -ge 40 && "$total" -ge 91 ]] || {
  echo "FAIL catalog shrank below the 91/40 audit record" >&2
  exit 1
}
[[ "${1:-}" == "--baseline-only" ]] && exit 0

python3 - "$ROOT" <<'PY'
import contextlib, csv, importlib.util, io, sys, tempfile
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("cs", root / "skills/spec/scripts/check_spec.py")
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)

# Open problems may only shrink on a fix. Raise this only when a newly measured
# hole is appended to the catalog, and say so in the commit — never to let a
# regression through.
OPEN_CEILING = 7

def quiet(fn, *a, **kw):
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return fn(*a, **kw)

def honesty(run, closing=False, spec_dir=Path("atk")):
    r = cs.Report()
    quiet(cs.check_run_honesty, spec_dir, run, r, structure_only=False, closing=closing)
    return r.errors

def tests_report(tests):
    r = cs.Report()
    quiet(cs.check_tests, Path("atk"), tests, [], r, structure_only=False)
    return r

hole = 0
passed = set()
def note(good, id_, detail):
    global hole
    if good:
        passed.add(id_); print(f"OK    {id_} — {detail}")
    else:
        hole += 1; print(f"HOLE  {id_} — {detail}", file=sys.stderr)

# --- deleted mechanisms must stay deleted (U3 hooks, U6 ALLOW_PARTIAL) ---
note(not (root / "scripts/hooks").exists()
     and not (root / "templates/.cursor/hooks.json").exists()
     and not (root / "templates/.claude/hooks").exists(),
     "hooks-gone", "no hooks subsystem to self-authorize")
note("ALLOW_PARTIAL" not in (root / "scripts/scaffold.sh").read_text(encoding="utf-8"),
     "allow-partial-gone", "scaffold cannot half-write a host")

# --- prose claims no longer buy anything: the close action is the gate ---
run_claim = "- 状态: `acceptance-passed`\n- 是否可以交付: `可交付`\n"
note(honesty(run_claim) == 0, "D01-nonclosing", f"err={honesty(run_claim)}")
note(honesty(run_claim, closing=True) >= 1, "claim-drift-neutralized",
     "ASCII-colon claim still cannot close without evidence")

head = "证伪: done\noverride: 用户要求自写\n### 追踪矩阵\n"
head += "| Requirement | Test | Implementation | Evidence | Result |\n|---|---|---|---|---|\n"

# a close must rest on one artifact; typing a Pass row is not enough
with tempfile.TemporaryDirectory() as td:
    h = Path(td); sd = h / "docs/specs/s1"; sd.mkdir(parents=True)
    typed = head + "| R-001 | T-001 | a.ts | kind=unit · 3 assertions | Pass |\n"
    note(honesty(typed, closing=True, spec_dir=sd) >= 1, "typed-close-rejected",
         "no artifact on disk")
    (h / "artifacts").mkdir(); (h / "artifacts/t001.log").write_text("ok\n", encoding="utf-8")
    real = head + "| R-001 | T-001 | a.ts | kind=unit · log=artifacts/t001.log | Pass |\n"
    note(honesty(real, closing=True, spec_dir=sd) == 0, "closing-evidence",
         "filled Pass row + real artifact closes")
    note(honesty(real, closing=True, spec_dir=sd) == 0, "real-pass-row-closes",
         "no new false alarm")

ovr = "- 当前模式：`build`\n- 结论：实现完成\noverride: 用户要求自写\noracle-freeze: intact\n红绿证据: N/A · 无自动化\n"
note(honesty(ovr) == 0, "override-1line", f"err={honesty(ovr)}")

eng = "- 当前模式：`build`\n- 结论：implementation complete\n"
note(honesty(eng) >= 1, "E08-english-claim", f"err={honesty(eng)}")

ph = head + "| R-001 | T-001 | | kind=… · | Pass / Fail / Blocked |\n"
note(honesty(ph, closing=True) >= 1, "placeholder-evidence", "template menus are not evidence")

mp = head + "| R-001 | T-001 | a.ts | kind=unit · log=nope/missing.log | Pass |\n"
note(honesty(mp, closing=True) >= 1, "missing-artifact", "cited path must exist")

# --- wordlists advise, they do not reject (U2 F08, U4 antipatterns) ---
def one_test(then_body):
    return (
        "## 测试索引\n\n| ID | Type | 标题 |\n|---|---|---|\n| T-001 | success | t |\n\n"
        f"## T-001\n\n### Given\n\n- env: local\n\n### When\n\n1. call it\n\n### Then\n\n{then_body}\n"
    )

weak = tests_report(one_test("- 用户可见：能打开"))
note(weak.errors == 0 and weak.warnings >= 1, "weak-oracle-warns",
     f"err={weak.errors} warn={weak.warnings}")
anti = tests_report(one_test("- 用户可见：引导走完，勾完清单"))
note(anti.errors == 0, "antipattern-warns", f"err={anti.errors}")

tpl_smoke = "- 产品冒烟（目标环境 · P6）：通过 | 未过 | Blocked+原因\n"
note(honesty(tpl_smoke) == 0, "template-smoke-not-a-claim", "menu row is not a prod claim")

# --- valid Markdown must not be rejected on formatting (U1 D13 / D14) ---
spaced = one_test("- 返回 200 且 total==3").replace("### ", "###  ")
note(tests_report(spaced).errors == 0, "atx-spacing-accepted", "###  Heading parses")
pipeless = (
    "## 测试索引\n\nID | Type | 标题\n--- | --- | ---\nT-001 | success | t\n\n"
    "## T-001\n\n### Given\n\n- local env\n\n### When\n\n1. call it\n\n"
    "### Then\n\n- 返回 200 且 total==3\n"
)
note(tests_report(pipeless).errors == 0, "pipeless-table-parsed", "outer pipes are optional")

# --- evidence binding (U5 E13 / E14) ---
with tempfile.TemporaryDirectory() as td:
    host = Path(td)
    logs = host / ".codex-dispatch-logs"; logs.mkdir()
    body = '{"type":"turn.completed","spec":"good-spec-v2","note":"' + "x" * 80 + '"}\n'
    (logs / "run-a.jsonl").write_text(body, encoding="utf-8")
    sd = host / "docs/specs/good-spec"; sd.mkdir(parents=True)
    ok, _ = cs.dispatch_evidence_valid("dispatch-run-id: run-a\n", sd)
    note(not ok, "spec-token-boundary", "good-spec-v2 log does not close good-spec")

    good_body = '{"type":"turn.completed","spec":"good-spec","note":"' + "x" * 80 + '"}\n'
    (logs / "run-b.jsonl").write_text(good_body, encoding="utf-8")
    ok2, _ = cs.dispatch_evidence_valid(
        "dispatch-run-id: run-b\ndispatch-run-id: run-missing\n", sd)
    note(not ok2, "all-run-ids-checked", "a second cited run-id is validated too")

# --- catalog accounting: every problem row names a probe or an open reason ---
rows = list(csv.DictReader((root / "scripts/fixtures/gate-cases.tsv").open(encoding="utf-8"),
                           delimiter="\t"))
open_rows, unbound = [], []
for r in rows:
    if r.get("PROBLEM") != "1":
        continue
    res, ref = (r.get("RESOLUTION") or "").strip(), (r.get("REF") or "").strip()
    if res == "open":
        open_rows.append(f"{r['CASE_ID']}:{ref or '?'}")
    elif res == "probe":
        if ref not in passed:
            unbound.append(f"{r['CASE_ID']}->{ref or '?'}")
    else:
        unbound.append(f"{r['CASE_ID']}:no-resolution")

for u in unbound:
    hole += 1
    print(f"HOLE  catalog-binding — {u}", file=sys.stderr)

total_problems = sum(1 for r in rows if r.get("PROBLEM") == "1")
print(f"== catalog problems={total_problems} "
      f"covered={total_problems - len(open_rows) - len(unbound)} "
      f"open={len(open_rows)} ({', '.join(sorted(open_rows)) or 'none'}) ==")
if len(open_rows) > OPEN_CEILING:
    hole += 1
    print(f"HOLE  open-ratchet — open={len(open_rows)} > ceiling {OPEN_CEILING}",
          file=sys.stderr)

print(f"== live probes HOLE={hole} OK={len(passed)} ==")
sys.exit(1 if hole else 0)
PY

# An unwired script looks like coverage and is not: orphan-refs must catch one.
# The name must be random — a literal here would appear in the corpus we scan.
probe="$(mktemp "$ROOT/skills/dispatch-codex/scripts/XXXXXXXX.sh")"
printf '#!/usr/bin/env bash\necho probe\n' >"$probe"
if bash "$ROOT/scripts/orphan-refs.sh" --strict >/dev/null 2>&1; then
  rm -f "$probe"
  echo "HOLE  unwired-script-detected — orphan-refs passed with an unreferenced script" >&2
  exit 1
fi
rm -f "$probe"
echo "OK    unwired-script-detected — an unreferenced script fails orphan-refs --strict"

# The discipline gate must fail closed when it cannot find a base to diff.
if env CI=1 GATE_DISCIPLINE_BASE=refs/__none__ \
    bash "$ROOT/scripts/check-gate-discipline.sh" >/dev/null 2>&1; then
  echo "HOLE  gate-discipline-fail-closed — passed with no base ref under CI" >&2
  exit 1
fi
echo "OK    gate-discipline-fail-closed — no base ref under CI exits 1"
