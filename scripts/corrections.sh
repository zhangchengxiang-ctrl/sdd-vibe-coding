#!/usr/bin/env bash
# Local transcript correction scanner — buckets to M1/M2/M3.
# Only scans <user_query> blocks (not plugin skill text echoed into transcripts).
#
# Raw keyword counts are not precision: a bucket fires on dispatch prompts and
# file paths too. scripts/fixtures/corrections-labels.tsv holds a hand-labelled
# sample (snippet hash + verdict, no transcript text) and this prints the
# measured precision against it.
#
# Pure local; no network; transcript text never leaves the machine.
# Usage:
#   bash scripts/corrections.sh [days=14]
#   bash scripts/corrections.sh [days] --emit-candidates   # for labelling
set -euo pipefail
DAYS="${1:-14}"
EMIT="${2:-}"
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

python3 - "$tmp.files" "$LOAD_RE" "$M1_RE" "$M2_RE" "$M3_RE" "$EMIT" <<'PY'
import csv, hashlib, json, re, sys
from pathlib import Path

files = [Path(l.strip()) for l in Path(sys.argv[1]).read_text().splitlines() if l.strip()]
load_re, m1, m2, m3 = (re.compile(x) for x in sys.argv[2:6])
emit = sys.argv[6] == "--emit-candidates"
uq = re.compile(r"<user_query>(.*?)</user_query>", re.S)
bucket_re = {"M1": m1, "M2": m2, "M3": m3}

loaded = 0
sessions = {k: 0 for k in bucket_re}
cands: dict[str, dict[str, str]] = {k: {} for k in bucket_re}

# This scanner's own patterns get pasted into dispatch prompts, which then land
# in <user_query> and match themselves. Drop those before counting.
SELF_RE = re.compile(r'M[123]_RE=|BUCKETS\s*=|LOAD_RE=|BUCKET_RE|"M[123]"\s*:\s*r"')


def snippet(text, m):
    s = text[max(0, m.start() - 60): m.end() + 60]
    return re.sub(r"\s+", " ", s).strip()

for f in files:
    try:
        text = f.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if not load_re.search(text):
        continue
    loaded += 1
    user = "\n".join(uq.findall(text))
    if not user:
        continue
    for k, rx in bucket_re.items():
        hits = [m for m in rx.finditer(user) if not SELF_RE.search(snippet(user, m))]
        if hits:
            sessions[k] += 1
        for m in hits:
            s = snippet(user, m)
            cands[k][hashlib.sha256(s.encode()).hexdigest()[:12]] = s

if emit:
    # Deterministic sample: hash order, 10 per bucket. Text stays on this machine.
    for k in bucket_re:
        for sha in sorted(cands[k])[:10]:
            print(f"{k}\t{sha}\t{cands[k][sha][:160]}")
    sys.exit(0)

labels_path = Path("scripts/fixtures/corrections-labels.tsv")
labels: dict[str, dict[str, str]] = {k: {} for k in bucket_re}
if labels_path.is_file():
    for row in csv.DictReader(labels_path.open(encoding="utf-8"), delimiter="\t"):
        labels.setdefault(row["BUCKET"], {})[row["SNIPPET_SHA"]] = row["LABEL"]

base_path = Path("scripts/fixtures/corrections-baseline.json")
base = json.loads(base_path.read_text(encoding="utf-8")) if base_path.is_file() else {}

print(f"sessions_with_plugin_load: {loaded}")
stale = []
for k in ("M1", "M2", "M3"):
    lab = labels.get(k, {})
    seen = [v for sha, v in lab.items() if sha in cands[k]]
    if lab and len(seen) < len(lab) / 2:
        stale.append(k)
    t = sum(1 for v in seen if v == "true")
    p = t / len(seen) if seen else None
    b = base.get("precision", {}).get(k)
    delta = f" baseline={b:.2f} Δ={p - b:+.2f}" if p is not None and b is not None else ""
    print(f"{k}: sessions={sessions[k]} candidates={len(cands[k])} "
          f"labelled={len(seen)}/{len(lab)} "
          f"precision={f'{p:.2f}' if p is not None else 'unlabelled'}"
          f" est_real={f'{sessions[k] * p:.0f}' if p is not None else '?'}{delta}")
if stale:
    print(f"NOTE: labelled sample aged out of the window for {', '.join(stale)} — "
          "re-draw with --emit-candidates and relabel before trusting precision")
print("--- corrections done (local only; exit 0) ---")
PY
rm -f "$tmp.files"
exit 0
