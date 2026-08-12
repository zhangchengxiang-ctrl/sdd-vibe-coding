#!/usr/bin/env bash
# Gate-case catalog + live probes. Replaces adversarial-rot-wave2 inline fixtures.
# Usage: bash scripts/gate-cases-runner.sh [--baseline-only]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSV="$ROOT/scripts/fixtures/gate-cases.tsv"
[[ -f "$TSV" ]] || { echo "missing $TSV" >&2; exit 2; }

problems=$(awk -F'\t' 'NR>1 && $8=="1"{c++} END{print c+0}' "$TSV")
total=$(awk -F'\t' 'NR>1{c++} END{print c+0}' "$TSV")
echo "== gate-cases catalog total=$total problems=$problems =="
[[ "$problems" -eq 40 && "$total" -eq 91 ]] || {
  echo "FAIL catalog baseline drift (want 91/40)" >&2
  exit 1
}
[[ "${1:-}" == "--baseline-only" ]] && exit 0

python3 - "$ROOT" <<'PY'
import contextlib, importlib.util, io, os, sys, tempfile
from pathlib import Path
root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("cs", root / "skills/spec/scripts/check_spec.py")
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)

def honesty(run, closing=False):
    r = cs.Report()
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err := io.StringIO()):
        cs.check_run_honesty(Path("atk"), run, r, structure_only=False, closing=closing)
    return r.errors

hole = ok = 0
def note(kind, id_, detail):
    global hole, ok
    if kind == "HOLE": hole += 1; print(f"HOLE  {id_} — {detail}", file=sys.stderr)
    else: ok += 1; print(f"OK    {id_} — {detail}")

# D01: non-closing does not gate on prose claims (action = --closing)
run_claim = "- 状态: `acceptance-passed`\n- 是否可以交付: `可交付`\n"
note("OK" if honesty(run_claim) == 0 else "HOLE", "D01-nonclosing",
     f"err={honesty(run_claim)}")

# closing requires positive evidence
run_close = run_claim + "证伪: done\noverride: 用户要求自写\n"
matrix_block = "\n### 追踪矩阵\n| Test | Result | Evidence |\n|---|---|---|\n| T-001 | Pass | kind=unit · ok |\n"
note("OK" if honesty(run_close + matrix_block, closing=True) == 0 else "HOLE",
     "closing-evidence", "override+kind matrix")

# override self-write without dispatch jsonl
ovr = "- 当前模式：`build`\n- 结论：实现完成\noverride: 用户要求自写\noracle-freeze: intact\n红绿证据: N/A · 无自动化\n"
note("OK" if honesty(ovr) == 0 else "HOLE", "override-1line", f"err={honesty(ovr)}")

# English completion claim (E08)
eng = "- 当前模式：`build`\n- 结论：implementation complete\n"
note("OK" if honesty(eng) >= 1 else "HOLE", "E08-english-claim", f"err={honesty(eng)}")

print(f"== live probes HOLE={hole} OK={ok} ==")
sys.exit(0)
PY
