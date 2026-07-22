# Version · <version-id>

| 字段 | 值 |
|------|-----|
| **ID** | `vYYYY.MM-<slug>` |
| **标题** | |
| **状态** | `draft` \| `in-progress` \| `review` \| `done` \| `archived` \| `cancelled`（**仅填一词**；备注写变更记录） |
| **Delivery Target** | `design-ready` \| `code-ready` \| `dev-effective` \| `production-delivered` \| `user-accepted` |
| **Current Gate** | `shape` \| `ready` \| `build` \| `verify` \| `demo` \| `deliver` \| `observe` |
| **Requirements Lock** | `open` \| `locked` \| `reopened` |
| **Owner** | |
| **Planning** | [roadmap 周计划](../../roadmap/) |
| **设计参考** | 宿主 docs（语言后缀随仓约定） |
| **创建** | YYYY-MM-DD |
| **合并** | |

## Agent 读序（Manifest）

**核心工件必有**；可选工件按触发条件从 [`_template/optional/`](../_template/optional/) 复制（触发表见 skill **`spec`**），复制后在下表登记。**不要为凑齐模板生成敷衍文件。**

| # | 文件 | 用途 | 门禁 |
|---|------|------|------|
| 0 | [`AGENTS.md`](../../../AGENTS.md) | 工程宪法 | — |
| 1 | [context.md](./context.md) | 本版本一页纸 | — |
| 2 | [requirements.md](./requirements.md) | 需求与 AC | — |
| 3 | [tasks.md](./tasks.md) | 开发任务 | — |
| 4 | [validation.md](./validation.md) | 合并前验收 | — |

可选工件（按需从 [`_template/optional/`](./optional/) **复制到 Spec 根**并插入读序；触发条件见 skill **`spec`**）：

| 文件 | 触发条件 | 门禁 |
|------|----------|------|
| `scope.md` · `product-design.md` · `research.md` | 升格切版（有设计稿来源） | — |
| `clarify.md` | 存在阻断当前 Slice 的产品歧义 | **Requirements Lock=locked 才进 build** |
| `design.md` | 非 trivial 技术方案 | clarify ✓（若有） |
| `experience-design.md` / `problem-map.md` | 模式 D（experience-design **必建**） | — |
| `regression-map.md` | 关版维护态关键旅程 | — |
| `test-plan.md` | 测试策略超出仓库默认 | — |
| `migration-design.md` / `threat-model.md` | DDL / 安全面 | 单向门 → 人审 |
| `commit-checklist.md` | 多会话协作提交约定 | — |

触发条件全文 → skill **`spec`**。

## 变更记录

| 日期 | 变更 |
|------|------|
| | 初版 |
