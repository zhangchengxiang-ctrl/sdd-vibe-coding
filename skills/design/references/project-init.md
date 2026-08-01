# 项目冷启动：Init / Onboard

> Shape 子流程真源。由 `vibe-coding` 在基线未齐时路由到本页；`design` Skill 执行。  
> 依赖：[`project-kind.md`](../../vibe-coding/references/project-kind.md)。

## 何时进入（优先于普通 Shape）

| 模式 | 信号 |
|---|---|
| **Init**（Greenfield） | 新开项目 / 从零搭 / 立项；无应用代码或几乎空仓；`AGENTS`/product 基线空 |
| **Onboard**（Brownfield） | 接入存量 / 学习这个 repo / 刚 scaffold；有代码或旧文档，SDD 基线空或明显落后 |
| 跳过 | `project.kind` 为 `plugin`/`other`；或 `software` 且 Tier 0 已齐、用户在谈具体功能切片 |

先判 [`project.kind`](../../vibe-coding/references/project-kind.md)（仅 `software` \| `plugin` \| `other`）。  
**仅 `software`** 走下方编码项目表单。`plugin` / `other`：不冷启动、不建表单。

## 前台交互（硬合同）

字段全集是 **Agent 内部水合清单**，不是用户问卷。

1. **推断 / 调研预填** → 输出**基线草案**（可读结论 + 推荐，带理由）；  
2. **需要你拍板** ≤ **5** 题（整轮 Init/Onboard 合计）；每题：推荐 / 为何问 / 可直接回复的选项；  
3. 未点名反对的推荐项 → **视为确认**；  
4. 用户确认后投影到寄存器 → 摘要「写了什么 / Tier 2 后补」；  
5. **完成 ≠ Build 授权**。

### 反模式

- 把 Tier 表贴给用户逐项填；「请补充以下 N 项」且无推荐；  
- 为 token / 竞品 / SLO 等 Tier 2 占拍板预算；  
- Onboard 静默删除用户级 `~/.cursor/rules` / skills。

### 5 问预算（默认只在必要时占用）

1. `project.kind`（探测不清）  
2. UI surface（product / consumer / 无 UI）  
3. 鉴权或租户（会改权限模型）  
4. `sdd.docs_root` 冲突  
5. 首个价值切片 / 明确不做（提示词未锁住）

其余用推断或 research + 推荐默认。

## 项目表单（内部）

### Tier 0（确认前须有值或明确推荐）

| 字段 | 落盘 |
|---|---|
| `project.kind`（**第 0 项**） | `AGENTS.md` |
| `init.mode`：greenfield / brownfield / hybrid | 会话；影响 scaffold profile |
| `sdd.docs_root` | `AGENTS.md` |
| 一句话产品 / 使命；做 / 不做 | `PRODUCT.md`、`foundation/mission.md` |
| 主要用户；≥1 角色；核心 Job（≤3） | `PRODUCT.md`、`personas-journeys.md` |
| 是否有 UI；`ui.surface` | `AGENTS` / `PRODUCT` / `DESIGN` |
| 产品名；技术栈；代码入口；默认分支 | `AGENTS.md` |
| DEM-001 种子 | `demand-pool.md` |

### Tier 1（首轮草案尽量齐）

本地命令与就绪度、Local URL、visitor_mode、组件库、anchor/反参考、成功信号、进程单元、分层/依赖、schema 真源、鉴权摘要、角色面、租户模型、（有 UI）浏览器工具；BF：文档链接表、gap 行、rules/skills 治理建议；product shell 或 consumer motif；buyer（B2B 含糊时）。

### Tier 2（后补，不挡完成）

品牌 token / knobs / 文案、Staging/Prod/监控/部署、共享资源、单向门、CI、合规/PII、i18n、渠道、SLO、第三方细节、C4/ADR、roadmap 细行、竞品、回归面。

### 来源标记

每字段：`infer` | `research` | `ask` | `recommend`；证据 `Verified` | `Unverified`。

### 禁止写入表单

Spec 用例、切片计划、密钥、P2/P3、整页 wiki 粘贴、实现类名/DDL、插件 design-standards 长文。

## Init（Greenfield）步骤

1. 判 kind；`plugin`/`other` → 结束（不走本页）。  
2. 需要时 `scaffold`（空仓倾向 `full`/`detect`）；scaffold ≠ 编码许可。  
3. 从用户提示词预填 Tier 0–1 → 基线草案。  
4. ≤5 拍板 → 确认后投影（`minimal` 也要按需创建 `PRODUCT`/`DESIGN`/`foundation`）。  
5. 进入普通 Shape（DEM 已种子化）或等用户下一意图。

## Onboard（Brownfield）步骤

1. 判 kind；确认 scaffold（`minimal`/`detect`；冲突 `--root=docs/sdd`）。  
2. 只读调研（见 [codebase-grounding.md](./codebase-grounding.md)）+ **治理盘点**：  
   - 用户级：`~/.cursor/rules`、`~/.cursor/skills`（及 Claude/Codex 等价）  
   - 项目级：仓内 rules/skills、`AGENTS.md`、宿主例外  
   - 产出：冲突分类（重复 / 矛盾 / 过时 / 可合并 / 应降级）+ **建议**（确认前不删用户级资产）  
3. 同一套基线草案（标 Verified/Unverified）+ 文档链接表 + 治理建议。  
4. ≤5 拍板 → 确认后投影 + 必要 gap 行。  
5. 再进普通 Shape。

## 完成定义

- Tier 0 齐（或推荐已被确认/沉默采纳）；  
- 用户确认投影；  
- 前台说明后补项与「尚不可写业务代码」（除非另授权）。  

状态：`drafting` → `confirmed`（→ 日后 `stale` 可再 Onboard 刷新）。
