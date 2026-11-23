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
expect "T-003 handoff 滚动的是最旧的（按日期）" grep -q "记录 01" "$G/docs/_archive/handoff/handoff-archive-2026-11.md"
expect "T-003 最新的留在 handoff" grep -q "记录 12" "$G/docs/handoff.md"
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
printf '# y\n见 [坏锚](x.md#不存在的节) 与 [同页](#也不存在)\n## 真标题\n见 [好锚](#真标题)\n' > "$B/docs/product/y.md"
echo "见 docs/old/rule" >> "$B/AGENTS.md"
head -c 50000 /dev/zero | tr '\0' 'a' >> "$B/docs/product/x.md"
mkdir -p "$B/docs/strange" "$B/docs/product/lonely"; echo x > "$B/docs/strange/a.md"; echo x > "$B/docs/product/lonely/a.md"
mkdir -p "$B/docs/reports"; cp "$HERE/../templates/docs/reports/_template.md" "$B/docs/reports/_template.md" 2>/dev/null || true
echo "| DEM-001 | 2026-11-01 | wish | 重复 | P2 | \`parked\` | | | |" >> "$B/docs/product/demand-pool.md"
out="$(python3 "$TOOL" check "$B" --today 2026-11-23 || true)"
for rule in C1 C2 C3 C4 C5 C6 C7 C9 C10; do expect "T-001 报出 $rule" grep -q "ERROR $rule" <<<"$out"; done
expect "T-001 C5 报出失效锚点" grep -q "锚点不存在 x.md#不存在的节" <<<"$out"
expect "T-001 C5 报出本页失效锚点" grep -q "本页锚点不存在 #也不存在" <<<"$out"
expect "T-001 C5 有效锚点不误报" bash -c "! grep -q '#真标题' <<<\"$out\""
expect "T-001 复审日当天算到期" bash -c "sed -i 's/review: 2000-01-01/review: 2026-11-23/' '$B/docs/architecture/gaps/GAP-002.md'; python3 '$TOOL' check '$B' --today 2026-11-23 | grep -q 'WARN C8 docs/architecture/gaps/GAP-002.md'"
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


# ---- regression cases from the 2026-11-23 blind review (one per finding) ----
X="$TMP/x"; cp -r "$G" "$X"; (cd "$X" && git add -A && git commit -qm base)
chk() { python3 "$TOOL" check "$X" --today 2026-11-23 "$@" 2>&1 || true; }
# R2 deleting a link target is an ERROR even when only the deletion is staged
printf '# l\n见 [v](victim.md)\n' > "$X/docs/product/linker.md"; echo "# v" > "$X/docs/product/victim.md"
(cd "$X" && git add -A && git commit -qm l && git rm -q docs/product/victim.md)
expect "R2 删除被链接文件被拦" bash -c "python3 '$TOOL' check '$X' --today 2026-11-23 --files --deleted docs/product/victim.md | grep -q 'ERROR C5 docs/product/linker.md'"
(cd "$X" && git reset -q --hard)
# R10 broken / variant generated markers
REGBAK="$TMP/_reg.bak"; cp "$X/docs/architecture/11-gap-register.md" "$REGBAK"
sed -i 's#<!-- /sdd:gen gaps -->##' "$X/docs/architecture/11-gap-register.md"
expect "R10 缺结束标记报 C4" bash -c "grep -q 'ERROR C4.*缺结束标记' <<<\"\$(python3 '$TOOL' check '$X' --today 2026-11-23)\""
cp "$REGBAK" "$X/docs/architecture/11-gap-register.md"
sed -i 's#<!-- sdd:gen gaps -->#<!--sdd:gen gaps-->#' "$X/docs/architecture/11-gap-register.md"
expect "R10 变体标记报 C4" bash -c "grep -q 'ERROR C4.*格式错误' <<<\"\$(python3 '$TOOL' check '$X' --today 2026-11-23)\""
cp "$REGBAK" "$X/docs/architecture/11-gap-register.md"
printf '# m\n正文提到 `<!-- sdd:gen NAME -->` 不算标记\n' > "$X/docs/product/mention.md"
expect "R10 行内代码里的标记不误报" bash -c "! grep -q 'mention.md' <<<\"\$(python3 '$TOOL' check '$X' --today 2026-11-23)\""
rm -f "$X/docs/product/mention.md"
# R11 / R12 link parsing
printf '# a\n[s](<no such.md>) [r][x]\n\n[x]: nope.md\n行内 `[c](inline-nope.md)` 不算\n[sp](my%%20file.md)\n' > "$X/docs/product/links.md"; echo "# m" > "$X/docs/product/my file.md"
out="$(chk)"
expect "R11 尖括号带空格的断链报出" grep -q "断链 no such.md" <<<"$out"
expect "R11 引用式断链报出" grep -q "断链 nope.md" <<<"$out"
expect "R12 行内代码里的链接不误报" bash -c "! grep -q inline-nope <<<\"\$1\"" _ "$out"
expect "R12 %20 解码后不误报" bash -c "! grep -q 'my%20file' <<<\"\$1\"" _ "$out"
rm -f "$X/docs/product/links.md" "$X/docs/product/my file.md"
# R13 C1 values
printf -- '---\ntitle: t\ntype: banana\nowner:\nupdated: 2026-11-24\n---\n# t\n' > "$X/docs/reports/notopic-20261124.md"
out="$(chk)"
expect "R13 空 owner 报出" grep -q "notopic-20261124.md: 头部缺字段或为空 owner, topic" <<<"$out"
expect "R13 type 不符报出" grep -q "type \`banana\` 应为 \`report\`" <<<"$out"
rm -f "$X/docs/reports/notopic-20261124.md"
sed -i 's/^owner: x$/owner: 这是一段很长很长很长很长的说明文字而不是负责人的名字，应该写在正文的字段表里而不是头部的 owner 字段/' "$X/docs/architecture/gaps/GAP-001.md"
expect "R13 owner 为长句报出" bash -c "grep -q 'owner 应是负责人名称' <<<\"\$(python3 '$TOOL' check '$X' --today 2026-11-23)\""
(cd "$X" && git checkout -q -- docs/architecture/gaps/GAP-001.md)
# R14 gap date / released
sed -i 's/review: 2099-01-01/review: TBD/' "$X/docs/architecture/gaps/GAP-001.md"
sed -i 's/status: open/status: done/; /^review:/d' "$X/docs/architecture/gaps/GAP-002.md"
out="$(chk)"
expect "R14 复审日非日期报出" grep -q "复审日 \`TBD\` 不是" <<<"$out"
expect "R14 done 缺 released 报出" grep -q "GAP-002.md: \`done\` 必须写 released" <<<"$out"
(cd "$X" && git checkout -q -- docs/architecture/gaps)
# R16 nested archive / stray gap file
mkdir -p "$X/docs/product/_archive"; echo "# o" > "$X/docs/product/_archive/old.md"; echo "# s" > "$X/docs/architecture/gaps/notes.md"
out="$(chk)"
expect "R16 嵌套归档目录报出" grep -q "ERROR C9 docs/product/_archive" <<<"$out"
expect "R16 gap 目录杂文件报出" grep -q "ERROR C9 docs/architecture/gaps/notes.md" <<<"$out"
rm -rf "$X/docs/product/_archive" "$X/docs/architecture/gaps/notes.md"
# R17 recreated after delete counts as new
mkdir -p "$X/docs/operations/requests"; printf -- '---\ntitle: q\ntype: request\nstatus: open\nowner: x\nupdated: 2026-11-01\n---\n# q\n' > "$X/docs/operations/requests/20261101-q.md"
(cd "$X" && git add -A && git commit -qm q && git rm -q docs/operations/requests/20261101-q.md && git commit -qm rmq)
mkdir -p "$X/docs/operations/requests"; printf '# q 无头部\n' > "$X/docs/operations/requests/20261101-q.md"
expect "R17 删除后重建按新文件报 ERROR" bash -c "grep -q 'ERROR C1 docs/operations/requests/20261101-q.md' <<<\"\$(python3 '$TOOL' check '$X' --today 2026-11-23)\""
rm -f "$X/docs/operations/requests/20261101-q.md"
# R15 host under an underscore path still finds versions
U="$TMP/_under/h"; mkdir -p "$TMP/_under"; cp -r "$G" "$U"
sed -i 's/^status: active$/status: bogus/' "$U/docs/iterations/2026-11/w4/v1/README.md"
expect "R15 下划线路径下仍检查版本" bash -c "python3 '$TOOL' check '$U' --today 2026-11-23 | grep -q 'C2 docs/iterations/2026-11/w4/v1/README.md'"
# R18 a version with no Spec can be cancelled by hand
mkdir -p "$X/docs/iterations/2026-11/w4/v2"; printf -- '---\ntitle: V2\ntype: iteration\nstatus: cancelled\nowner: x\nupdated: 2026-11-23\n---\n# V2\n' > "$X/docs/iterations/2026-11/w4/v2/README.md"
python3 "$TOOL" gen "$X" >/dev/null
expect "R18 无 Spec 版本可手工取消" grep -q "^status: cancelled" "$X/docs/iterations/2026-11/w4/v2/README.md"
# R9 undated standing section stays; age by date
printf '\n## 常驻约定\n\n- 不要滚动我\n' >> "$G/docs/handoff.md"
python3 "$TOOL" gen "$G" >/dev/null
expect "R9 不带日期的常驻节不被滚动" grep -q "常驻约定" "$G/docs/handoff.md"
# R5 / R6 / R7 / R8 mv
M2="$TMP/mv2"; cp -r "$G" "$M2"; mkdir -p "$M2/docs/product/sub"
printf '# s\n[up](../a.md)\n' > "$M2/docs/product/sub/s.md"; echo "# a" > "$M2/docs/product/a.md"; echo "# sibling" > "$M2/docs/product/sub.md"
printf '见 docs/product/sub.md 与 docs/product/sub/s.md\n' > "$M2/docs/product/ref.md"
printf 'x:\n\tcat docs/product/a.md\n' > "$M2/Makefile"; printf '{"p": "docs/product/a.md"}\n' > "$M2/cfg.json"
printf '# crlf\r\n[a](a.md)\r\n' > "$M2/docs/product/crlf.md"
(cd "$M2" && git add -A && git commit -qm m2); echo "# untracked" > "$M2/docs/product/untracked.md"
expect "R5 有未跟踪源时整体拒绝" bash -c "! python3 '$TOOL' mv '$M2' docs/product/a.md docs/product/a2.md docs/product/untracked.md docs/product/u2.md"
expect "R5 拒绝时第一项也没动" test -f "$M2/docs/product/a.md"
rm -f "$M2/docs/product/untracked.md"
expect "R6 目录带尾斜杠可移动" python3 "$TOOL" mv "$M2" docs/product/sub/ docs/archive2/x/
expect "R6 移走文件的出链已改写" grep -q "](../../product/a.md)" "$M2/docs/archive2/x/s.md"
expect "R7 同名 .md 不被误改" grep -q "docs/product/sub.md" "$M2/docs/product/ref.md"
expect "R7 目录前缀引用已改写" grep -q "docs/archive2/x/s.md" "$M2/docs/product/ref.md"
python3 "$TOOL" mv "$M2" docs/product/a.md docs/product/a-renamed.md >/dev/null
expect "R8 Makefile 引用已改写" grep -q "docs/product/a-renamed.md" "$M2/Makefile"
expect "R8 json 引用已改写" grep -q "docs/product/a-renamed.md" "$M2/cfg.json"
expect "R8 CRLF 保留" bash -c "grep -q $'\r' '$M2/docs/product/crlf.md' && grep -q 'a-renamed.md' '$M2/docs/product/crlf.md'"

echo "--- selftest-docs-lint: pass=$PASS fail=$FAIL ---"
[[ $FAIL -eq 0 ]]
