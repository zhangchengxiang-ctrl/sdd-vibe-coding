#!/usr/bin/env bash
# Verify the Spec Run delivery model and plugin package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

echo '== package =='
python3 /home/zcx/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py "$ROOT"
python3 /home/zcx/.codex/skills/.system/skill-creator/scripts/quick_validate.py "$ROOT/skills/vibe-coding"

echo '== no legacy control-plane paths =='
# 静默防回归：skills/templates/scripts/evals 不得复活旧路径语法。
# 排除 verify.sh 自身（守卫字符串会自击）。
if rg -n 'tasks/|routes/|Work Order|Task Index|Route v1|T-[0-9]{3}' \
  -g '!scripts/verify.sh' \
  "$ROOT/skills" "$ROOT/templates" "$ROOT/scripts" "$ROOT/evals"; then
  echo 'ERROR: legacy control-plane syntax remains' >&2
  exit 1
fi

echo '== Spec Run contract =='
rg -q '一个确认的 Spec 是唯一交付单元' "$ROOT/skills/vibe-coding/references/workflow-contract.md"
rg -q '该批次开始到结果收齐期间，禁止修改代码' "$ROOT/skills/vibe-coding/references/workflow-contract.md"
rg -q '统一 Repair 方案' "$ROOT/skills/vibe-coding/references/workflow-contract.md"
rg -q '本 Spec 的唯一运行态' "$ROOT/templates/docs/specs/_template/spec-run.md"

echo '== scaffold =='
HOST="$TEMP_ROOT/host"
mkdir -p "$HOST"
bash "$ROOT/scripts/scaffold.sh" "$HOST" >/dev/null
bash "$HOST/scripts/check-docs.sh" "$HOST"

echo '== active Spec =='
SPEC_ID='v2099.01-spec-run-fixture'
cp -R "$HOST/docs/specs/_template" "$HOST/docs/specs/$SPEC_ID"
python3 - "$HOST/docs/specs/$SPEC_ID" "$HOST/docs/reference/handoff.md" "$SPEC_ID" <<'PY'
from pathlib import Path
import sys

spec = Path(sys.argv[1])
handoff = Path(sys.argv[2])
spec_id = sys.argv[3]
for path in spec.rglob('*.md'):
    text = path.read_text(encoding='utf-8').replace('<version-id>', spec_id)
    text = text.replace('vYYYY.MM-<slug>', spec_id)
    if path.name == 'VERSION.md':
        text = text.replace('| **状态** | `draft` |', '| **状态** | `ready` |')
    path.write_text(text, encoding='utf-8')
lines = handoff.read_text(encoding='utf-8').splitlines()
row = f'| [{spec_id}](../specs/{spec_id}/VERSION.md) | ready | build | current-chat | local | N/A | N/A | N/A | none | none | none | continue Build | |'
for index, line in enumerate(lines):
    if line.startswith('| | | |'):
        lines[index] = row
        break
handoff.write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
bash "$HOST/scripts/check-docs.sh" "$HOST"

echo '== hygiene =='
git -C "$ROOT" diff --check
echo 'RESULT: PASS — Spec Run contract and scaffold validated'
