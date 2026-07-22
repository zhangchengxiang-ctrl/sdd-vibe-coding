---
name: vibe-coding
description: >-
  Spec-Driven Delivery 主入口（跨项目）。Intake 沉淀 · Owner 排期 · Build 落地；
  验收换轨用 `.next-rail.md`。触发：我希望 / 优化 / 排期 / 帮我构建 / vibe / 开工 /
  改代码 / 修 bug / 验收。注意：「优化」未说开始做 → Intake，勿直接改码。
---

# Vibe Coding（Agent Boot）

**跨仓库主入口。** 项目细节只从宿主 `AGENTS.md` + `docs/` 读取，禁止写死宿主路径/命令/URL。

**默认只读**：宿主 `AGENTS.md` + 用户点名的 Spec/设计。其它 skill / 工厂文仅在任务触发时读。

**主循环**：Wish → Ground → Shape → Spec → Build → Verify → Demo → Deliver → Observe → Learn。  
角色解耦 → [`references/role-rails.md`](./references/role-rails.md)。  
已挂 Spec → [`references/execution-discipline.md`](./references/execution-discipline.md)。  
验收不 OK → [`references/acceptance-to-remediation.md`](./references/acceptance-to-remediation.md)。

空仓（无 `AGENTS.md`/`docs/`）→ 先跑插件 `scripts/scaffold.sh`，再判轨。

---

## 0. 先判轨 + 产品记忆闸（IRON）

| 轨 | 何时 | 可写 | 禁止 |
|----|------|------|------|
| **Intake** | 我希望 / 优化·改进 / 未说开始做 | demand-pool；可选 modules | Spec、业务代码 |
| **Owner** | 排期 / 优先 / 拍板切片 | 池；升格 Spec；`.next-rail` | 业务实现 |
| **Build** | 明示开始做 + 已锁切片 / 挂 Spec | specs + 代码 | 静默扩 In |

歧义 → **默认 Intake**。假 Build 信号（优化 / 编号清单 / 截图 /「应该…」）→ **一律 Intake**。  
唯一口语闸门：**明示**「开始做 / 实现 / 按这个来 / 构建」且切片已确认；或已挂 Spec / remediation。

**产品记忆闸**（规则 `01`）：写业务代码前须有 (a) modules / DEM / 归属 spec，或 (b) 明示开始做于已锁切片。皆无 → 只写 `docs/product/` + 一屏 Shape。

---

## 1. 开工读序

| 序 | 读 | 目的 |
|----|-----|------|
| 1 | 宿主 `AGENTS.md` 相关段 | 环境、命令、红线 |
| 2 | 判轨后：Intake→demand-pool；Owner→池+handoff；Build→点名 Spec | 本轨真源 |
| 3 | 按需：handoff、system-map、modules、专项 skill | 路由/架构时才读 |

约 10 分钟内须有本轨有效产出或真实 blocker。  
WIP 上限、验证命令、浏览器验收方式 → **读宿主 `AGENTS.md` / `docs/README*`**（勿写死）。

**切版**：默认 **A 忠实升格**（In=设计全文；Phase 只排 tasks）。**B 排期裁剪**仅用户明示。细则 → `spec` skill。  
面向测试 / 体验切版 → `spec` skill。塑形 → `product-design-package`，**禁止**设计讨论直接建 Spec。

**验收 3 硬钉**：禁同会话改合同；「验收完成」= 矩阵终态齐全 ≠ 全绿；完成必带范围标签。换轨写 `.next-rail.md` + 聊天一行指针。

---

## 2. 需求定级

- **规模轴** → 文档义务（Trivial/Small 可不新建 Spec；Non-trivial/Major 必须）  
- **风险轴** → 验证深度（单向门清单以宿主 `AGENTS.md` 为准）  
- **Hotfix**：生产不可用 → 最小修复后 24h 内补质量事件  

Major：用户明确批准后再编码；计划落盘 Spec。

---

## 3. 编码前诊断（bug / non-trivial）

挂载 spec · 表象 · 根因 · 最小方案 · 风险。机械/纯 docs 免仪式。  
红线：优化/清单当 Build；设计直接建 Spec；验收不 OK 只开修 bug 无体验方案；碰单向门未升验证。

---

## 4. 路由

| 场景 | Skill |
|------|-------|
| 产品包 / 优化塑形 | `product-design-package` |
| 切版 / 消歧 / 收敛 / 分析 / 质量 | `spec` |
| 验收→修复 | `acceptance-to-remediation` + `spec` 模式 D |
| 验证 / 部署 / UI | **宿主 `AGENTS.md` 指向的 skill/命令** |

执行层循环 → `execution-discipline.md`。

---

## 5. 收尾

Done = 声明的 Delivery Target + 范围标签。先守判轨与产品记忆闸（`02-gate-precedence`）。  
最小相关验证；已挂 Spec 才回填；handoff 只改本行；Demo/Delivery Card 分类反馈。  
何时改 `AGENTS.md`：仅宪法级事实变化。
