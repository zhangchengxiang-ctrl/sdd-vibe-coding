#!/usr/bin/env bash
# Close a version (iteration) — 版本关闭.
#
# A version lives at <docs>/iterations/<yyyy-mm>/<w>/<version>/ and its Specs are its child dirs.
# The time-bucketed path is permanent: closing changes the status word, it moves nothing.
#
# Does, in order:
#   1. every Spec in the version is `archived` (close-spec) or `cancelled` (else FAIL, listing them)
#   2. retro.md exists and at least one line differs from the template (else FAIL)
#   3. the version README front matter `status:` -> archived
#
# Usage:
#   bash scripts/close-iteration.sh <host-root> <version-id>
#   make close-iteration HOST=/path ITERATION=id
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -lt 2 ]]; then
  echo "usage: close-iteration.sh <host-root> <version-id>" >&2
  exit 2
fi
HOST="$(cd "$1" && pwd)"
IT="$2"
SPEC_PATHS="$ROOT/skills/spec/scripts/spec_paths.py"

set +e
IT_DIR="$(python3 "$SPEC_PATHS" find-iteration "$HOST" "$IT")"; fst=$?
set -e
if [[ "$fst" -eq 3 ]]; then
  echo "close-iteration: FAIL version id $IT is not unique (see above)" >&2; exit 1
fi
if [[ "$fst" -ne 0 || -z "$IT_DIR" ]]; then
  echo "close-iteration: FAIL no version $IT under the docs root's iterations/ (a version dir has README.md with front matter \`type: iteration\`)" >&2
  exit 1
fi

python3 - "$IT_DIR" "$ROOT/templates/docs/iterations/_template/retro.md" "$SPEC_PATHS" <<'PYCHK'
import importlib.util, re, sys
from pathlib import Path

it_dir, tmpl, sp_path = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
spec = importlib.util.spec_from_file_location("sp", sp_path); sp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sp)

print("== close-iteration 1/3: member Specs closed ==")
STATUS = (re.compile(r"^\|\s*\*{0,2}状态\*{0,2}\s*\|\s*`?([A-Za-z-]+)", re.M),
          re.compile(r"^\s*-\s*(?:Status|状态)\s*[:：]\s*`?([A-Za-z-]+)", re.M))
open_specs = []
specs = sp.specs_of(it_dir)
for s in specs:
    text = (s / "VERSION.md").read_text(encoding="utf-8")
    m = next((mm for rx in STATUS if (mm := rx.search(text))), None)
    word = m.group(1) if m else "(no status)"
    if word not in ("archived", "cancelled"):
        open_specs.append(f"  - {s.name}: {word}")
print(f"close-iteration: {len(specs)} Spec(s) in {it_dir.name}")
if open_specs:
    print("close-iteration: FAIL these Specs are not closed (close-spec them, or mark them `cancelled` and record why in decisions.md):", file=sys.stderr)
    print("\n".join(open_specs), file=sys.stderr)
    sys.exit(1)

print("== close-iteration 2/3: retro written ==")
retro = it_dir / "retro.md"
if not retro.is_file():
    print("close-iteration: FAIL retro.md missing", file=sys.stderr); sys.exit(1)
def body(p):
    t = re.sub(r"^---\n.*?\n---\n", "", p.read_text(encoding="utf-8"), flags=re.S)
    return [l.strip() for l in t.splitlines() if l.strip() and not l.lstrip().startswith(("#", ">"))]
template = set(body(tmpl)) if tmpl.is_file() else set()
if not [l for l in body(retro) if l not in template]:
    print("close-iteration: FAIL retro.md is still the template (no line has been answered)", file=sys.stderr); sys.exit(1)
print("close-iteration: retro ok")

print("== close-iteration 3/3: README status -> archived ==")
p = it_dir / "README.md"
t = p.read_text(encoding="utf-8")
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
if re.search(r"^status:\s*archived\s*$", m.group(1), re.M):
    print("close-iteration: already archived"); sys.exit(0)
fm = (re.sub(r"^status:.*$", "status: archived", m.group(1), count=1, flags=re.M)
      if re.search(r"^status:", m.group(1), re.M) else m.group(1) + "\nstatus: archived")
p.write_text("---\n" + fm + "\n---\n" + t[m.end():], encoding="utf-8")
print("close-iteration: README status -> archived (nothing moved)")
PYCHK
echo "close-iteration: DONE — 确认本版本仍成立的结论已晋升到常青文档或 ADR（五条规则第 3 条）"
