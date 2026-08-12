#!/usr/bin/env bash
# Local transcript correction scanner — buckets to M1/M2/M3.
# Only scans <user_query> blocks (not plugin skill text echoed into transcripts).
# Prints counts + precision upper bound vs whole-file matches. Pure local; no network.
# Usage: bash scripts/corrections.sh [days=14]
set -euo pipefail
DAYS="${1:-14}"
LOAD_RE='vibe-coding|workflow-contract|check_spec|codex-dispatch|sdd-vibe|wish-orchestrate|dispatch-codex'
M1_RE='推卸|甩锅|入口太|什么提示词都能|格式|不是.*Vibe|词表.*打架|关版.*归档|project\.kind|默认.*coding'
M2_RE='叠补丁|打补丁|又写.*规则|停写|去掉.*规则|从来没有.*删除|垃圾规则|干净的重构'
M3_RE='骗人|作弊|敷衍|轻易就通过|形式|齐套|Checklist|checklist|验收.*假|假冒烟|评分不变|说优化完'

echo "== corrections (last ${DAYS}d; user_query only) =="
tmp=$(mktemp)
: >"$tmp.files"
for r in "$HOME/.cursor/projects" "$HOME/.claude/projects"; do
  [[ -d "$r" ]] || continue
  find "$r" -name '*.jsonl' -mtime -"$DAYS" -type f 2>/dev/null >>"$tmp.files" || true
done

python3 - "$tmp.files" "$LOAD_RE" "$M1_RE" "$M2_RE" "$M3_RE" <<'PY'
import re, sys
from pathlib import Path
files = [Path(l.strip()) for l in Path(sys.argv[1]).read_text().splitlines() if l.strip()]
load_re, m1, m2, m3 = (re.compile(x) for x in sys.argv[2:6])
uq = re.compile(r"<user_query>(.*?)</user_query>", re.S)
loaded = any_m = user_m = {k: 0 for k in ("M1", "M2", "M3")}
# fix: need separate dicts
any_c = {"M1": 0, "M2": 0, "M3": 0}
user_c = {"M1": 0, "M2": 0, "M3": 0}
loaded = 0
samples = {"M1": [], "M2": [], "M3": []}
bucket_re = {"M1": m1, "M2": m2, "M3": m3}
for f in files:
    try:
        text = f.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if not load_re.search(text):
        continue
    loaded += 1
    user = "\n".join(uq.findall(text))
    for k, rx in bucket_re.items():
        if rx.search(text):
            any_c[k] += 1
        if user and rx.search(user):
            user_c[k] += 1
            if len(samples[k]) < 3:
                m = rx.search(user)
                samples[k].append(user[max(0, m.start()-20): m.end()+20].replace("\n", " ")[:80])
print(f"sessions_with_plugin_load: {loaded}")
for k in ("M1", "M2", "M3"):
    a, u = any_c[k], user_c[k]
    p = f"{u/a:.2f}" if a else "n/a"
    print(f"{k}_in_user_query: {u}  (whole_file={a} precision_upper={p})")
print("--- samples (user_query) ---")
for k in ("M1", "M2", "M3"):
    for s in samples[k]:
        print(f"  [{k}] {s}")
print("--- corrections done (local only; exit 0) ---")
PY
rm -f "$tmp.files"
exit 0
