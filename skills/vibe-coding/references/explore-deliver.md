# Explore / Deliver（意图优先）

> **形式是 Deliver 的安全网，不是 Explore 的默认输出。**  
> 真源：入口 [`../SKILL.md`](../SKILL.md)；写码授权 [`gates.md`](./gates.md)。

## 每轮先判（先于 Rail / 卡片 / 读全套 skill）

1. **用户这一轮要什么？** 答案 / 方案 / 读码 / 实现 / 验收 / 发布  
2. **Explore 还是 Deliver？**（见下表）  
3. **只有 Deliver** 才启用阶段全套（Shape 卡片、Plan 五件套、Build 编排、关版话术）

## 模式

| 模式 | 何时 | Agent 做什么 | 禁止 |
|------|------|--------------|------|
| **Explore** | 帮我想想 / 聊聊 / 怎么设计 / 读代码 / 调研 / 对比方案；用户说「先别走 SDD / 不要卡片 / 直接给方案」 | 直接回答用户 Job：读代码、查资料、给可证伪结论；口语为主 | 默认不出理解卡；不对齐 docs 冒充设计；不请「确认方案」 |
| **Deliver** | 就按这个做 / 确认方案 / 切 Spec / 开始做 / 关版 / 发布 / 用户要「落盘 / 给 PM / 准备实施」 | 走 SDD 阶段闸 + 形式安全网（方案闸、Spec、Oracle、证据） | 跳过 gates / 弱 Oracle 关版 |

**默认：** 未命中 Deliver 高信号 → **Explore**。  
「我希望 / 我想要 / 设计方案 / 优化体验」在 Explore 下 ≠ 只能写 `docs/product/`（见 gates）。

## Explore 实质闸（防表演）

Explore 回复须至少满足 **其一**（否则视为在表演，须补做）：

- **代码锚点**：引用真实路径 / 调用点 / 配置（Read/Grep 后）  
- **可证伪断言**：成功 vs 失败各一句，或两态命令草案  
- **机制/权衡**：分层、状态传播、边界、代价（infra / 后端 / 平台）  
- **产品场景**：一个可观察用户结果 + 非目标（UI / 产品，仍不必卡片）

命中 [`scheme-antipatterns.md`](../../design/references/scheme-antipatterns.md)（齐套灌水、文档对齐、形式走查等）→ **不得**请确认方案或宣称可交付。

## Deliver 分叉（形式在此启用）

| 任务 | 入口 |
|------|------|
| UI / 产品切片 | Shape 卡片（opt-in）→ 方案闸 → Plan |
| infra / 平台机制 | 直入 Plan → [`infra-mechanism-brief.md`](../../spec/references/infra-mechanism-brief.md) |
| 已确认 Spec | Build → Verify → 关版 |
| 发布 | Deploy P4+ |

## 懒加载（勿 burn 首轮上下文）

| 常驻 | 进入时再读 |
|------|------------|
| 本文件 + [`gates.md`](./gates.md) 摘要 | Shape → `design`；Plan → `spec`；Build → `rails` + 边界；Verify → `testing`；Deploy → `deploy` |
| 宿主 `AGENTS.md`（software + SDD 命中时） | 有 UI → LOAD-MAP；infra Plan → infra-mechanism-brief |

## 用户逃生句

用户任一表述生效：**「先别走 SDD」** / **「不要卡片」** / **「直接读代码给方案」** / **「这轮 Explore」**  
→ 强制 Explore + 实质闸；仅当用户后续说落盘/开始做/确认方案才进 Deliver。
