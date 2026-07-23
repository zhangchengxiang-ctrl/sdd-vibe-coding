---
name: vibe-coding
description: >-
  Spec-Driven Delivery 主入口（跨项目）。Intake 沉淀 · Owner 排期 · Build 落地；
  验收换轨用 `.next-rail.md` 一行指针。触发：我希望 / 优化体验 / 排期 / 帮我构建 / vibe / 开工 /
  改代码 / 修 bug / 验收 / 发布。注意：「优化」未说开始做 → Intake，勿直接改码。
---

# Vibe Coding（Agent Boot）

**跨仓库主入口。** 细节只读宿主 `AGENTS.md` + `docs/`；禁止写死宿主路径/URL/命令。  
体系地图 → 插件根 [`SYSTEM.md`](../../SYSTEM.md)（概念→权威文件索引）。

**主循环**（唯一图 → `SYSTEM.md` §1）：  
`Wish → Ground → Shape → Spec → Build → Verify → Demo → Deliver → Observe → Learn`  
角色细则 → [`role-rails.md`](./references/role-rails.md) · 执行 → [`execution-discipline.md`](./references/execution-discipline.md) · 验收修复 → [`acceptance-to-remediation.md`](./references/acceptance-to-remediation.md) · handoff → [`handoff.md`](./references/handoff.md) · UX → [`ux-standards.md`](./references/ux-standards.md)。  
空仓 → 跑 `bash <plugin>/scripts/scaffold.sh <dir>`（生成 `AGENTS.md` · `docs/` · sdd-enabled · rules 副本；**不算**产品记忆闸放行）再判轨。

---

## 0. 先判轨 + 产品记忆闸（IRON）

| 合同 | 权威（禁止本文件复述正文） |
|------|---------------------------|
| 判轨 Intake/Owner/Build · 假 Build · trivial | `rules/00-judge-track-first.mdc` |
| 产品记忆闸 (a)/(b) | `rules/01-product-memory-first.mdc` |
| 门禁优先级 | `rules/02-gate-precedence.mdc` |

歧义 → **默认 Intake**。口语闸门：**明示**「开始做 / 实现 / 按这个来 / 构建」且切片已确认；或已挂 Spec / remediation。  
**DEM / modules 草稿 ≠ 编码许可证**（见 `rules/01`）。验收会话 → **Accept** 只测（见 `rules/00`）。

### Wish Intake（未说开始做）

Ground →（必要）联网调研 → Clarify（≤1–3 高价值问）→ Shape（Intake/Kickoff Card）→ 沉淀 DEM / 成块走 `design` → **停**（禁 Spec、禁编码）。  
卡片模板与可写路径 → [`role-rails.md`](./references/role-rails.md)。  
说「开始做」且切片确认 → Owner 锁合同 + Plan Approval + `spec` → **新对话 Build**（或 `.next-rail`）。本地可密码登录 → 自助换号，勿 Decision「请你登录」。

---

## 1. 开工读序

1. 宿主 `AGENTS.md` 相关段 → 2. 判轨真源（池 / Spec）→ 3. 按需 handoff · modules · 专项 skill。  
探测与真源优先级 → `SYSTEM.md` §2.1。约 10 分钟内须有本轨产出或真实 blocker。WIP / 验证命令 → 读宿主（勿写死）。

**物理层 / 切版 / 验收 3 硬钉** → 分别见 `execution-discipline` · `skills/spec` · `acceptance-to-remediation`（不在此复述）。

---

## 2. 需求定级（两轴 · 权威）

- **规模轴** → 文档义务  
- **风险轴** → 验证深度（单向门清单以宿主 `AGENTS.md` 为准）

| 规模 | Spec | Docs |
|------|------|------|
| Trivial | 不需要 | Docs: N/A + 理由 |
| Small fix | 已有可更新；否则可不建 | 默认 N/A |
| Non-trivial | 必须 `docs/specs/<id>/` | 验收相关矩阵 + validation |
| Major | Spec + 聊天 Plan Approval | system-map + 必要时 ADR |

**Hotfix**：生产不可用 → 最小修复后 24h 内补质量事件；暴露体系问题则登 gap-register。  
实现中途碰单向门或新增产品/API/DB 合同 → 停下补计划与验收条件。文件数本身不触发升级。

---

## 3. 编码前诊断（bug / non-trivial）

挂载 spec · 表象 · 根因 · 最小方案 · 风险。机械/纯 docs 免仪式。  
红线：优化/清单当 Build；设计直接建 Spec；升格当 PM 裁剪；无 scenario 矩阵就编码；验收不 OK 只修 bug；碰单向门未升验证。

---

## 4. 路由

| 场景 | Skill |
|------|-------|
| 产品包 / 优化塑形 | `design` |
| 切版 / 消歧 / 收敛 / 分析 | `spec` |
| 验收→修复 | `acceptance-to-remediation` + `spec` 模式 D |
| 验证 / 报告模板 | `testing` |
| 验证 / UI / 部署命令 | **宿主 `AGENTS.md` 指向的 skill/命令** |
| 空仓骨架 | `scripts/scaffold.sh`（见上） |

轨步骤细则 → [`role-rails.md`](./references/role-rails.md)。无独立 `commands/` 模块。

---

## 5. 收尾

Done / 范围标签 / 禁止假完成 → **权威** `rules/03-completion-gate.mdc`。  
先守判轨与产品记忆闸（`02-gate-precedence`）。最小相关验证；已挂 Spec 才回填（`04`）；handoff 只改本行（`05`）。  
何时改 `AGENTS.md`：仅宪法级事实变化。
