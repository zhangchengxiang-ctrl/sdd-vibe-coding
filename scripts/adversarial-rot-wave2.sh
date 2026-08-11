#!/usr/bin/env bash
# Adversarial wave-2: deeper bypass probes for rot-mechanisms-v5.
# Classifies each probe as BLOCKED | HOLE | INFO.
# Exit 0 always after printing summary (wave-1 remains the hard gate).
# Usage: bash scripts/adversarial-rot-wave2.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="${ADV_W2_OUT:-/tmp/sdd-rot-adv-wave2}"
mkdir -p "$OUT"
BLOCKED=0
HOLE=0
INFO=0
ROWS=()

note() { # kind id detail
  local kind="$1" id="$2" detail="$3"
  ROWS+=("$kind|$id|$detail")
  case "$kind" in
    BLOCKED) BLOCKED=$((BLOCKED + 1)); echo "BLOCKED  $id — $detail" ;;
    HOLE)    HOLE=$((HOLE + 1));    echo "HOLE     $id — $detail" >&2 ;;
    INFO)    INFO=$((INFO + 1));    echo "INFO     $id — $detail" ;;
  esac
}

echo "== adversarial-rot-wave2 =="
echo "ROOT=$ROOT OUT=$OUT"
export ROOT OUT ADV_W2_OUT="$OUT"

python3 - <<'PY'
import contextlib, importlib.util, io, json, os
from pathlib import Path

root = Path(os.environ["ROOT"]).resolve()
spec = importlib.util.spec_from_file_location(
    "check_spec", root / "skills/spec/scripts/check_spec.py"
)
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)


def honesty(run: str):
    r = cs.Report()
    err = io.StringIO()
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
        cs.check_run_honesty(Path("atk"), run, r, structure_only=False)
    return {
        "errors": r.errors,
        "blocked": r.errors >= 1,
        "stderr": [l for l in err.getvalue().splitlines() if l.startswith("ERROR")],
    }


def tests_then(then: str):
    r = cs.Report()
    body = f"""
## 索引
| ID | Type | R |
|----|------|---|
| T-001 | success | R-1 |

## T-001
### Given
- 新用户进入主路径
### When
- 用户执行动作
### Then（Oracle）
- 用户可见：{then}
"""
    err = io.StringIO()
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
        cs.check_tests(Path("atk"), body, [], r, structure_only=False)
    regex = cs.then_is_lazy_path_oracle(then)
    return {
        "then": then,
        "lazy_regex": regex,
        "errors": r.errors,
        "blocked": r.errors >= 1,
        "real_hole": (not regex and r.errors == 0),
        "stderr": [l for l in err.getvalue().splitlines() if "ERROR" in l or "WARN" in l],
    }


results = {"lazy": [], "honesty": {}, "misc": {}}

# H1 corpus — synonym escapes for scheme-antipatterns rows 1/2/5
lazy_corpus = [
    ("H1a-checklist-slang", "新手任务单全部打钩，教学流程正式收官。"),
    ("H1b-tour-syn", "导览动画走到末页并自动退场。"),
    ("H1c-focus-syn", "光标落进编辑区域，输入态高亮。"),
    ("H1d-drawer-syn", "侧滑面板弹出并停在展开态。"),
    ("H1e-rate-syn", "学习进度条冲到满格，徽章点亮。"),
    ("H1f-onboarding", "用户把 onboarding 步骤一个个点完。"),
    ("H1g-coachmark", "coach mark 序列播放到最后一帧。"),
    ("H1h-right-sheet", "right sheet 展开并固定。"),
    ("H1i-textarea-en", "textarea 获得焦点且闪烁光标。"),
    ("H1j-known-control", "勾完 checklist / Tour 播完 / lesson 完成率 100%"),
]
for cid, then in lazy_corpus:
    row = tests_then(then)
    row["id"] = cid
    results["lazy"].append(row)

# H2 — euphemism without freeze / literal 实现完成
euph = [
    ("H2a-jiaojuan", "Build 已经交卷，功能代码全部落袋。"),
    ("H2b-impl-done", "Implementation is done; ready for verification."),
    ("H2c-dev-ended", "本切片开发工作已全部结束。"),
]
for cid, phrase in euph:
    run = f"""
- 状态：`building`
- 当前模式：`build`

{phrase}

oracle-freeze: intact
红绿证据: red exit=1 · green exit=0

## 批次结果
| 结果 |
|------|
| Pass |
"""
    row = honesty(run)
    row["id"] = cid
    row["phrase"] = phrase
    results["honesty"][cid] = row

# Control: freeze without dispatch still blocked
results["honesty"]["B2-control-freeze"] = honesty(
    """
- 当前模式：`build`
- 实现冻结时间：2026-08-11T00:00:00Z
oracle-freeze: intact
红绿证据: N/A · 无自动化
## 批次结果
| 结果 |
|------|
| Pass |
"""
)

# H3 — fake override: polish without real polish context
results["honesty"]["H3-fake-override-polish"] = honesty(
    """
- 当前模式：`build`
- 实现冻结时间：2026-08-11T00:00:00Z
override: polish
oracle-freeze: intact
红绿证据: N/A · polish
## 批次结果
| 结果 |
|------|
| Pass |
"""
)

# H4 — nonexistent dispatch-run-id
results["honesty"]["H4-fake-dispatch-id"] = honesty(
    """
- 当前模式：`build`
- 实现冻结时间：2026-08-11T00:00:00Z
dispatch-run-id: totally-fake-id-999
oracle-freeze: intact
红绿证据: N/A · 无自动化
## 批次结果
| 结果 |
|------|
| Pass |
"""
)

# H5 — forged verify-deliver stamp (static text only)
results["honesty"]["H5-forged-verify-stamp"] = honesty(
    """
- 状态：`acceptance-passed`
- 当前模式：`verify`
- 是否可以交付：`可交付`
verify-deliver: ok · 2099-01-01T00:00:00Z
证伪: falsify done
## 已验证的用户结果
用户能完成主路径
## 批次结果
| 结果 |
|------|
| Pass |
"""
)

# Weak smoke Then — should still be blocked (control)
results["lazy"].append(
    {**tests_then("页面能打开且有数据"), "id": "C-weak-smoke"}
)

# Install vs repo drift
repo = root / "skills/vibe-coding"
inst = Path.home() / ".cursor/plugins/local/sdd-vibe-coding/skills/vibe-coding"
drift = {"repo": str(repo), "install": str(inst), "files": {}}
for rel in [
    "SKILL.md",
    "references/gates.md",
    "references/wish-delivery.md",
    "references/workflow-contract.md",
]:
    r, i = repo / rel, inst / rel
    drift["files"][rel] = {
        "repo": r.is_file(),
        "install": i.is_file(),
        "same_bytes": (r.is_file() and i.is_file() and r.read_bytes() == i.read_bytes()),
    }
results["misc"]["install_drift"] = drift

out = Path(os.environ.get("ADV_W2_OUT", "/tmp/sdd-rot-adv-wave2"))
out.mkdir(parents=True, exist_ok=True)
(out / "probes.json").write_text(
    json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps({"ok": True, "out": str(out / "probes.json")}))
PY

# Classify from JSON
python3 - <<'PY'
import json, os
from pathlib import Path
out = Path(os.environ.get("ADV_W2_OUT", "/tmp/sdd-rot-adv-wave2"))
data = json.loads((out / "probes.json").read_text())
lines = []

def emit(kind, id_, detail):
    lines.append(f"{kind}\t{id_}\t{detail}")

for row in data["lazy"]:
    cid = row["id"]
    if cid == "H1j-known-control" or cid == "C-weak-smoke":
        emit("BLOCKED" if row["blocked"] else "HOLE", cid,
             f"blocked={row['blocked']} regex={row.get('lazy_regex')}")
    else:
        # synonym attacks: hole if not blocked
        emit("HOLE" if row["real_hole"] else "BLOCKED", cid,
             f"then={row['then'][:40]}…")

for cid, row in data["honesty"].items():
    if cid.startswith("B2-control"):
        emit("BLOCKED" if row["blocked"] else "HOLE", cid, f"errors={row['errors']}")
    elif cid.startswith("H2"):
        emit("HOLE" if not row["blocked"] else "BLOCKED", cid, row.get("phrase", "")[:50])
    elif cid.startswith("H3") or cid.startswith("H4") or cid.startswith("H5"):
        emit("HOLE" if not row["blocked"] else "BLOCKED", cid, f"errors={row['errors']}")
    else:
        emit("INFO", cid, f"errors={row['errors']}")

d = data["misc"]["install_drift"]["files"]
mism = [k for k, v in d.items() if v["repo"] != v["install"] or (v["repo"] and v["install"] and not v["same_bytes"])]
# wish-delivery both absent is OK (same)
mism = [k for k in mism if not (k.endswith("wish-delivery.md") and not d[k]["repo"] and not d[k]["install"])]
if mism:
    emit("HOLE", "H6-install-drift", ",".join(mism))
else:
    emit("BLOCKED", "H6-install-drift", "repo==install for SKILL/gates/contract; wish absent both")

(out / "classify.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

while IFS=$'\t' read -r kind id detail; do
  [[ -z "${kind:-}" ]] && continue
  note "$kind" "$id" "$detail"
done <"$OUT/classify.tsv"

# Extra: slogan ratchet still gone; window
if ! grep -E 'grep -q .*禁止因普通调研|grep -q .*关版 ≠ 上线' scripts/check-contract-sync.sh >/dev/null 2>&1; then
  note BLOCKED "A1-still-gone" "no slogan greps"
else
  note HOLE "A1-still-gone" "slogan greps returned"
fi

echo
echo "======== WAVE2 SUMMARY ========"
printf '%s\n' "${ROWS[@]}"
echo "BLOCKED=$BLOCKED HOLE=$HOLE INFO=$INFO"
echo "json=$OUT/probes.json"
# Non-zero if any HOLE (surfaces residual risk); callers may ignore.
[[ "$HOLE" -eq 0 ]]
