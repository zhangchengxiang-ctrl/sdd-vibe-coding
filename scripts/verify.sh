#!/usr/bin/env bash
# Verify the Codex-only plugin package, contracts, fixtures, and host scaffold.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
LIVE_EVAL="${LIVE_EVAL:-0}"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; FAIL=1; }

echo "== manifest =="
package_version="$(python3 -c "import json; print(json.load(open('$ROOT/package.json'))['version'])")"
plugin_name="$(python3 -c "import json; print(json.load(open('$ROOT/.codex-plugin/plugin.json'))['name'])")"
plugin_version="$(python3 -c "import json; print(json.load(open('$ROOT/.codex-plugin/plugin.json'))['version'])")"
if [[ "$plugin_name" == "sdd-superpowers" ]]; then
  pass "Codex plugin name=$plugin_name"
else
  fail "unexpected Codex plugin name=$plugin_name"
fi
plugin_base_version="${plugin_version%%+*}"
if [[ "$package_version" == "$plugin_version" ]]; then
  pass "version aligned ($plugin_version)"
elif [[ "$package_version" == "$plugin_base_version" \
    && "$plugin_version" == *"+codex."* ]]; then
  pass "base version aligned with local cachebuster ($plugin_version)"
else
  fail "version drift package=$package_version plugin=$plugin_version"
fi
echo "== required structure =="
required=(
  .codex-plugin/plugin.json
  .agents/plugins/marketplace.json
  README.md
  package.json
  scripts/install.sh
  scripts/scaffold.sh
  scripts/check-docs.sh
  scripts/check-docs.py
  scripts/verify-contract-fixtures.py
  scripts/run-live-evals.py
  evals/routing-contract-cases.json
  evals/routing-output.schema.json
  skills/vibe-coding/SKILL.md
  skills/vibe-coding/agents/openai.yaml
  skills/vibe-coding/references/workflow-contract.md
  skills/vibe-coding/references/task-contract.md
  skills/vibe-coding/references/workspace-contract.md
  skills/vibe-coding/references/codex-worktree-execution.md
  skills/vibe-coding/references/evidence-contract.md
  skills/vibe-coding/references/incident-contract.md
  skills/design/SKILL.md
  skills/design/agents/openai.yaml
  skills/spec/SKILL.md
  skills/spec/agents/openai.yaml
  skills/testing/SKILL.md
  skills/testing/agents/openai.yaml
  skills/debug/SKILL.md
  skills/debug/agents/openai.yaml
  templates/AGENTS.md
  templates/docs/reference/claims.md
  templates/docs/specs/_template/technical-plan.md
  templates/docs/specs/_template/scenario-spec.md
  templates/docs/specs/_template/tasks/T-001.md
  templates/docs/specs/_template/routes/T-001.next-rail.md
  templates/docs/specs/_template/evidence/README.md
  templates/docs/operations/incidents/_template.md
)
for path in "${required[@]}"; do
  [[ -e "$ROOT/$path" ]] && pass "$path" || fail "missing $path"
done

echo "== Codex-only surface =="
tracked_forbidden="$(
  while IFS= read -r path; do
    if [[ -e "$ROOT/$path" ]] \
      && [[ "$path" =~ (^|/)(\.cursor|\.claude|rules)(/|$)|\.mdc$ ]]; then
      printf '%s\n' "$path"
    fi
  done < <(git -C "$ROOT" ls-files)
)"
if [[ -z "$tracked_forbidden" ]]; then
  pass "no tracked incompatible behavior rules"
else
  fail "tracked incompatible surfaces:"
  printf '%s\n' "$tracked_forbidden"
fi

source_roots=("$ROOT/skills" "$ROOT/templates" "$ROOT/scripts" "$ROOT/README.md")
for pattern in 'alwaysApply' 'CLAUDE_PLUGIN_ROOT' '\.cursor/' '\.claude/' '\.mdc'; do
  if rg -n -e "$pattern" "${source_roots[@]}" \
      --glob '!verify.sh' --glob '!*.json' >"$TEMP_ROOT/forbidden.txt" 2>/dev/null; then
    fail "forbidden compatibility reference /$pattern/:"
    sed -n '1,20p' "$TEMP_ROOT/forbidden.txt"
  else
    pass "no compatibility reference /$pattern/"
  fi
done

echo "== skill metadata and boundaries =="
for skill in vibe-coding design spec testing debug; do
  file="$ROOT/skills/$skill/SKILL.md"
  ui_file="$ROOT/skills/$skill/agents/openai.yaml"
  rg -q "^name: $skill$" "$file" && pass "$skill name" || fail "$skill frontmatter name"
  rg -q '^description:' "$file" && pass "$skill description" || fail "$skill description"
  if [[ "$skill" == "vibe-coding" ]]; then
    rg -q '^  default_prompt: ".+"' "$ui_file" \
      && pass "$skill default prompt" || fail "$skill default prompt is missing"
  else
    rg -F -q "\$$skill" "$ui_file" \
      && pass "$skill default prompt" || fail "$skill default prompt must mention \$$skill"
  fi
done
rg -q 'allow_implicit_invocation: true' \
  "$ROOT/skills/vibe-coding/agents/openai.yaml" \
  && pass "vibe-coding is the implicit entry" || fail "vibe-coding implicit policy"
for skill in design spec testing debug; do
  rg -q 'allow_implicit_invocation: false' \
    "$ROOT/skills/$skill/agents/openai.yaml" \
    && pass "$skill is explicit/routed only" || fail "$skill implicit policy"
done
rg -q '一个执行上下文.*只挂载一个 Rail 和一个主目标' \
  "$ROOT/skills/vibe-coding/references/workflow-contract.md" \
  && pass "one execution owner / one rail" || fail "missing execution boundary"
rg -q 'local | codex-worktree | git-worktree' \
  "$ROOT/skills/vibe-coding/references/workspace-contract.md" \
  && pass "conditional workspace modes" || fail "workspace modes missing"
rg -q 'production-restored' \
  "$ROOT/skills/vibe-coding/references/incident-contract.md" \
  && pass "incident completion semantics" || fail "incident contract incomplete"

echo "== routing contract fixtures =="
if python3 "$ROOT/scripts/verify-contract-fixtures.py" \
    "$ROOT/evals/routing-contract-cases.json"; then
  pass "routing contract fixtures"
else
  fail "routing contract fixtures"
fi
if [[ "$LIVE_EVAL" == "1" ]]; then
  if python3 "$ROOT/scripts/run-live-evals.py" --all; then
    pass "all live Codex routing evaluations"
  else
    fail "live Codex routing evaluations"
  fi
elif python3 "$ROOT/scripts/run-live-evals.py" --case shape-vague-wish --dry-run; then
  pass "live Codex eval runner available (behavior not executed)"
else
  fail "live Codex eval runner"
fi
echo "== fresh explicit scaffold =="
host="$TEMP_ROOT/host"
mkdir -p "$host"
bash "$ROOT/scripts/scaffold.sh" "$host" >/dev/null
for path in \
  AGENTS.md \
  docs/README.md \
  docs/reference/handoff.md \
  docs/reference/claims.md \
  docs/specs/_template/technical-plan.md \
  docs/specs/_template/tasks/T-001.md \
  docs/specs/_template/routes/T-001.next-rail.md \
  docs/operations/incidents/_template.md \
  scripts/check-docs.sh \
  scripts/check-docs.py
do
  [[ -e "$host/$path" ]] && pass "scaffold $path" || fail "scaffold missing $path"
done
for path in .cursor .claude CLAUDE.md; do
  [[ ! -e "$host/$path" ]] && pass "scaffold omits $path" || fail "scaffold created $path"
done
before="$(find "$host" -type f -printf '%P %s\n' | sort)"
bash "$ROOT/scripts/scaffold.sh" "$host" >/dev/null
after="$(find "$host" -type f -printf '%P %s\n' | sort)"
if [[ "$before" == "$after" ]]; then
  pass "scaffold idempotent file set"
else
  fail "scaffold changed files on second run"
fi

echo "== scaffold docs check =="
if bash "$host/scripts/check-docs.sh" "$host"; then
  pass "fresh scaffold passes docs check"
else
  fail "fresh scaffold docs check"
fi
echo "== active Spec docs check =="
spec_id="v2099.01-fixture"
cp -R "$host/docs/specs/_template" "$host/docs/specs/$spec_id"
python3 - "$host/docs/specs/$spec_id" "$spec_id" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for path in root.rglob("*.md"):
    text = path.read_text(encoding="utf-8")
    text = text.replace("<version-id>", sys.argv[2])
    text = text.replace("vYYYY.MM-example", sys.argv[2])
    text = text.replace("`vYYYY.MM-<slug>`", f"`{sys.argv[2]}`")
    if path.name == "VERSION.md":
        text = text.replace("| **状态** | `draft` |", "| **状态** | `ready` |")
    if path.name == "T-001.md":
        text = text.replace(
            "- Requirement / Scenario：",
            "- Requirement / Scenario：R-001 / SC-001 / SC-002",
        )
    path.write_text(text, encoding="utf-8")
PY
python3 - "$host/docs/reference/handoff.md" "$spec_id" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
row = (
    f"| [{sys.argv[2]}](../specs/{sys.argv[2]}/VERSION.md) "
    f"| T-001 | build | ready | current-chat | local | N/A | N/A "
    f"| [route](../specs/{sys.argv[2]}/routes/T-001.next-rail.md) "
    f"| N/A | none | none | execute | |"
)
lines = path.read_text(encoding="utf-8").splitlines()
heading = lines.index("## 活跃工作")
lines[heading + 4] = row
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if bash "$host/scripts/check-docs.sh" "$host"; then
  pass "ready Spec with Task and handoff passes docs check"
else
  fail "active Spec docs check"
fi

echo "== docs negative cases =="
bad_task_host="$TEMP_ROOT/bad-task"
cp -R "$host" "$bad_task_host"
python3 - "$bad_task_host/docs/reference/handoff.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(
    text.replace("| T-001 | build |", "| T-999 | build |", 1),
    encoding="utf-8",
)
PY
if bash "$bad_task_host/scripts/check-docs.sh" "$bad_task_host" \
    >"$TEMP_ROOT/bad-task.out" 2>&1; then
  fail "docs check accepted handoff with missing named Task"
elif rg -F -q "missing named Task 'T-999'" "$TEMP_ROOT/bad-task.out"; then
  pass "docs check rejects the named missing Task for the expected reason"
else
  fail "missing Task case failed for an unexpected reason"
fi
bad_claim_host="$TEMP_ROOT/bad-claim"
cp -R "$host" "$bad_claim_host"
python3 - "$bad_claim_host/docs/reference/claims.md" "$spec_id" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
rows = (
    f"| C-001 | resource | test-db | {sys.argv[2]} | T-001 | a | local | active | now | |\n"
    f"| C-002 | resource | test-db | {sys.argv[2]} | T-001 | b | local | active | now | |"
)
lines = path.read_text(encoding="utf-8").splitlines()
for index, line in enumerate(lines):
    if line.startswith("| |") and "active / released" in line:
        lines[index:index + 1] = rows.splitlines()
        break
else:
    raise SystemExit("claims placeholder row not found")
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if bash "$bad_claim_host/scripts/check-docs.sh" "$bad_claim_host" \
    >"$TEMP_ROOT/bad-claim.out" 2>&1; then
  fail "docs check accepted duplicate active resource Claims"
elif rg -F -q "claim conflict resource:test-db" "$TEMP_ROOT/bad-claim.out"; then
  pass "docs check rejects duplicate Resource for the expected reason"
else
  fail "duplicate Resource case failed for an unexpected reason"
fi

bad_claim_type_host="$TEMP_ROOT/bad-claim-type"
cp -R "$host" "$bad_claim_type_host"
python3 - "$bad_claim_type_host/docs/reference/claims.md" "$spec_id" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
row = f"| C-legacy | task | T-001 | {sys.argv[2]} | T-001 | a | local | released | now | now |"
lines = path.read_text(encoding="utf-8").splitlines()
for index, line in enumerate(lines):
    if line.startswith("| |") and "active / released" in line:
        lines[index] = row
        break
else:
    raise SystemExit("claims placeholder row not found")
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
if bash "$bad_claim_type_host/scripts/check-docs.sh" "$bad_claim_type_host" \
    >"$TEMP_ROOT/bad-claim-type.out" 2>&1; then
  fail "docs check accepted a legacy task Claim"
elif rg -F -q "invalid Type 'task'; only 'resource' is allowed" \
    "$TEMP_ROOT/bad-claim-type.out"; then
  pass "docs check rejects legacy Claim types for the expected reason"
else
  fail "legacy Claim type case failed for an unexpected reason"
fi

bad_route_host="$TEMP_ROOT/bad-route"
cp -R "$host" "$bad_route_host"
python3 - "$bad_route_host/docs/specs/$spec_id/routes/T-001.next-rail.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("route_version: 1\n", "", 1), encoding="utf-8")
PY
if bash "$bad_route_host/scripts/check-docs.sh" "$bad_route_host" \
    >"$TEMP_ROOT/bad-route.out" 2>&1; then
  fail "docs check accepted a Route without route_version"
elif rg -F -q "missing required Route v1 fields ['route_version']" \
    "$TEMP_ROOT/bad-route.out"; then
  pass "docs check rejects incomplete Route v1 for the expected reason"
else
  fail "Route v1 case failed for an unexpected reason"
fi

bad_evidence_host="$TEMP_ROOT/bad-evidence"
cp -R "$host" "$bad_evidence_host"
python3 - "$bad_evidence_host" "$spec_id" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
spec_id = sys.argv[2]
task = root / f"docs/specs/{spec_id}/tasks/T-001.md"
task.write_text(
    task.read_text(encoding="utf-8").replace(
        "## 终态\n\n`ready`",
        "## 终态\n\n`passed`",
    ),
    encoding="utf-8",
)
handoff = root / "docs/reference/handoff.md"
handoff.write_text(
    handoff.read_text(encoding="utf-8").replace(
        "| T-001 | build | ready |",
        "| T-001 | build | passed |",
        1,
    ),
    encoding="utf-8",
)
PY
if bash "$bad_evidence_host/scripts/check-docs.sh" "$bad_evidence_host" \
    >"$TEMP_ROOT/bad-evidence.out" 2>&1; then
  fail "docs check accepted passed Task without actual evidence"
elif rg -F -q "passed Task requires actual result and evidence path" \
    "$TEMP_ROOT/bad-evidence.out"; then
  pass "docs check rejects missing Task evidence for the expected reason"
else
  fail "Task evidence case failed for an unexpected reason"
fi

echo "== repository hygiene =="
if python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
missing = []
for source_root in (root / "skills", root / "templates"):
    for path in source_root.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        for raw in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            target = raw.split("#", 1)[0]
            if (
                not target
                or "://" in target
                or "<" in target
                or ">" in target
                or "（" in target
            ):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                missing.append(f"{path.relative_to(root)} -> {target}")
if missing:
    print("\n".join(f"MISSING: {item}" for item in missing), file=sys.stderr)
    raise SystemExit(1)
PY
then
  pass "relative Markdown links resolve"
else
  fail "broken relative Markdown links"
fi
if python3 - "$ROOT" <<'PY'
from pathlib import Path
import json
import subprocess
import sys

root = Path(sys.argv[1])
bad = []
untracked = subprocess.run(
    ["git", "-C", str(root), "ls-files", "--others", "--exclude-standard"],
    check=True,
    capture_output=True,
    text=True,
).stdout.splitlines()
for relative in untracked:
    path = root / relative
    if path.is_file() and path.suffix in {".md", ".py", ".sh", ".yaml", ".json"}:
        for number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if line != line.rstrip():
                bad.append(f"{relative}:{number}")
for path in [
    root / "package.json",
    root / ".codex-plugin/plugin.json",
    root / ".agents/plugins/marketplace.json",
]:
    json.loads(path.read_text(encoding="utf-8"))
if bad:
    print("TRAILING WHITESPACE: " + ", ".join(bad), file=sys.stderr)
    raise SystemExit(1)
PY
then
  pass "all source text clean; JSON parses"
else
  fail "source text or JSON hygiene"
fi
if git -C "$ROOT" diff --check; then
  pass "git diff --check"
else
  fail "git diff --check"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
if [[ "$LIVE_EVAL" == "1" ]]; then
  echo "RESULT: PASS — Codex-only SDD $plugin_version deterministic + live behavior"
else
  echo "RESULT: PASS — Codex-only SDD $plugin_version deterministic checks only"
  echo "Run LIVE_EVAL=1 bash scripts/verify.sh for behavior acceptance."
fi
