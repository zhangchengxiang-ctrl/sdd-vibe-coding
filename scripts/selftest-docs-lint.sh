#!/usr/bin/env bash
# selftest-docs-lint.sh — offline selftest for scripts/sdd_docs.py (check C1..C10, gen, mv).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOL="$HERE/sdd_docs.py"
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); echo "PASS  $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL  $1" >&2; }
expect() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }

TMP="$(mktemp -d)"; [[ -n "${KEEP:-}" ]] && echo "keep: $TMP" || trap 'rm -rf "$TMP"' EXIT

mk_good() {
  local h="$1"; mkdir -p "$h"; cd "$h"; git init -q; git config user.email t@t; git config user.name t
  cat > AGENTS.md <<'EOF'
# host
- SDD docs root: docs
- SDD archive dir: _archive
- SDD gap register: docs/architecture/11-gap-register.md
- SDD gap dir: docs/architecture/gaps
- SDD legacy paths: docs/old/
EOF
  mkdir -p docs/product docs/architecture/gaps docs/iterations/2026-11/w4/v1/v2026.11-a docs/reports docs/operations/incidents docs/_archive/handoff
  cat > docs/README.md <<'EOF'
# map
## 这份文档该放哪
| `product/` | `architecture/` | `iterations/` | `reports/` | `operations/` | `_archive/` |
EOF
  cat > docs/iterations/README.md <<'EOF'
# iterations
<!-- sdd:gen iterations -->
<!-- /sdd:gen iterations -->
EOF
  cat > docs/iterations/2026-11/w4/v1/README.md <<'EOF'
---
title: V1
type: iteration
status: draft
owner: x
updated: 2026-11-23
---
# V1
EOF
  printf '# Version\n\n| **状态** | `in-progress` |\n' > docs/iterations/2026-11/w4/v1/v2026.11-a/VERSION.md
  cat > docs/reports/README.md <<'EOF'
# reports
<!-- sdd:gen reports -->
<!-- /sdd:gen reports -->
EOF
  cat > docs/reports/topic-20261101.md <<'EOF'
---
title: 一份报告
type: report
owner: x
updated: 2026-11-01
topic: 示例
---
# 一份报告
EOF
  cat > docs/operations/incidents/README.md <<'EOF'
# incidents
<!-- sdd:gen incidents -->
<!-- /sdd:gen incidents -->
EOF
  cat > docs/operations/incidents/20261101-x.md <<'EOF'
---
title: 事故 X
type: incident
status: done
owner: x
updated: 2026-11-01
---
# 事故 X
EOF
  cat > docs/architecture/11-gap-register.md <<'EOF'
# gaps
<!-- sdd:gen gaps -->
<!-- /sdd:gen gaps -->
EOF
  for n in 001 002; do cat > docs/architecture/gaps/GAP-$n.md <<EOF
---
id: GAP-$n
title: 缺口 $n
type: gap
status: open
severity: high
owner: x
created: 2026-11-01
review: 2099-01-01
---
# GAP-$n
EOF
  done
  cat > docs/product/demand-pool.md <<'EOF'
# 需求池
## 条目
| ID | 日期 | 类型 | 用户问题 / 目标 | 优先级建议 | 状态 | 复审日 | 说明 | 真源 / 版本 / 报告 |
|---|---|---|---|---|---|---|---|---|
| DEM-001 | 2026-11-01 | wish | 想法 | P2 | `open` | 2099-01-01 | | |
| DEM-002 | 2026-11-01 | wish | 暂缓 | park | `parked` | 2099-01-01 | 等 X | |
EOF
  { echo "# 交接"; echo; echo "<!-- sdd:gen handoff-active -->"; echo "<!-- /sdd:gen handoff-active -->"; echo;
    for i in $(seq -w 1 12); do echo "## 2026-11-$i · 记录 $i"; echo; echo "- 见 [需求池](product/demand-pool.md)"; echo; done; } > docs/handoff.md
  git add -A; git commit -qm init
  cd - >/dev/null
}

G="$TMP/good"; mk_good "$G"
python3 "$TOOL" gen "$G" >/dev/null
expect "T-003 gen 第二次无差异" python3 "$TOOL" gen "$G" --check
expect "T-002 合规夹具 0 错误" python3 "$TOOL" check "$G" --today 2026-11-23
expect "T-003 版本索引含 v1" grep -q "2026-11/w4/v1" "$G/docs/iterations/README.md"
expect "T-003 版本状态推导为 active" grep -q "^status: active" "$G/docs/iterations/2026-11/w4/v1/README.md"
expect "T-003 报告按 topic 分组" grep -q "### 示例" "$G/docs/reports/README.md"
expect "T-003 事故索引" grep -q "20261101-x" "$G/docs/operations/incidents/README.md"
expect "T-003 gap 总表 2 条在办" grep -q "在办（2）" "$G/docs/architecture/11-gap-register.md"
expect "T-003 handoff 只留 10 节" test "$(grep -c '^## 2026' "$G/docs/handoff.md")" = 10
expect "T-003 handoff 滚动进归档" grep -q "记录 12" "$G/docs/_archive/handoff/handoff-archive-2026-11.md"
expect "T-003 归档内链接已改写" grep -q "](../../product/demand-pool.md)" "$G/docs/_archive/handoff/handoff-archive-2026-11.md"

# T-004 hand edit of a generated section
sed -i '/2026-11\/w4\/v1/d' "$G/docs/iterations/README.md"
out="$(python3 "$TOOL" check "$G" --today 2026-11-23 || true)"
expect "T-004 手改生成段报 C4" grep -q "ERROR C4" <<<"$out"
python3 "$TOOL" gen "$G" >/dev/null

# T-001 one violation per rule
B="$TMP/bad"; cp -r "$G" "$B"
sed -i 's/^owner: x$/topic: 示例/' "$B/docs/reports/topic-20261101.md"; printf -- '---\ntitle: r\ntype: report\nstatus: active\nowner: x\nupdated: 2026-11-01\n---\n# r\n' > "$B/docs/reports/new-20261102.md"
printf -- '---\ntitle: bad\ntype: report\nowner: x\nupdated: 2026-11-01\n---\n# bad [x](nope.md)\n' > "$B/docs/reports/undated.md"
sed -i 's/status: open/status: partial/' "$B/docs/architecture/gaps/GAP-001.md"
sed -i 's/^id: GAP-002/id: GAP-009/' "$B/docs/architecture/gaps/GAP-002.md"
sed -i 's/review: 2099-01-01/review: 2000-01-01/' "$B/docs/architecture/gaps/GAP-002.md"
printf '# C1\n\n| **状态** | active |\n' > "$B/docs/product/C1-x.md"
printf '# x\n见 [a](missing.md) 与 docs/old/thing\n' > "$B/docs/product/x.md"
echo "见 docs/old/rule" >> "$B/AGENTS.md"
head -c 50000 /dev/zero | tr '\0' 'a' >> "$B/docs/product/x.md"
mkdir -p "$B/docs/strange" "$B/docs/product/lonely"; echo x > "$B/docs/strange/a.md"; echo x > "$B/docs/product/lonely/a.md"
mkdir -p "$B/docs/reports"; cp "$HERE/../templates/docs/reports/_template.md" "$B/docs/reports/_template.md" 2>/dev/null || true
echo "| DEM-001 | 2026-11-01 | wish | 重复 | P2 | \`parked\` | | | |" >> "$B/docs/product/demand-pool.md"
out="$(python3 "$TOOL" check "$B" --today 2026-11-23 || true)"
for rule in C1 C2 C3 C4 C5 C6 C7 C9 C10; do expect "T-001 报出 $rule" grep -q "ERROR $rule" <<<"$out"; done
expect "T-001 C8 为警告" grep -q "WARN C8" <<<"$out"
expect "T-001 退出码非 0" bash -c "! python3 '$TOOL' check '$B' --today 2026-11-23"
expect "T-001 --files 之外的错误降级" bash -c "python3 '$TOOL' check '$B' --today 2026-11-23 --files docs/README.md | grep -q 'WARN C6 AGENTS.md'"

# T-005 / T-006 mv
M="$TMP/mv"; cp -r "$G" "$M"
mkdir -p "$M/docs/product/sub"
printf '# b\n见 [c](../architecture/11-gap-register.md)\n' > "$M/docs/product/b.md"
printf '# a\n见 [b](b.md)\n' > "$M/docs/product/a.md"
(cd "$M" && git add -A && git commit -qm b)
expect "T-005 mv 成功" python3 "$TOOL" mv "$M" docs/product/b.md docs/product/sub/b.md
expect "T-005 入链已改写" grep -q "](sub/b.md)" "$M/docs/product/a.md"
expect "T-005 出链已改写" grep -q "](../../architecture/11-gap-register.md)" "$M/docs/product/sub/b.md"
expect "T-006 目标已存在则拒绝" bash -c "! python3 '$TOOL' mv '$M' docs/product/a.md docs/product/sub/b.md"
expect "T-006 拒绝时不改文件" grep -q "](sub/b.md)" "$M/docs/product/a.md"

echo "--- selftest-docs-lint: pass=$PASS fail=$FAIL ---"
[[ $FAIL -eq 0 ]]
