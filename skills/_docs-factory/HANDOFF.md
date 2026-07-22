# Handoff 约定（跨仓库）

> `docs/reference/handoff.md` = **并行路由表**，不是单功能日记。  
> 执行真源 = `docs/specs/<id>/`；handoff 只索引「有哪些线在跑」。

## 职责分界

| 写入位置 | 放什么 | 不放什么 |
|----------|--------|----------|
| `specs/<id>/context.md` | 本版目标、约束、关键路径 | 其他功能的进度 |
| `specs/<id>/tasks.md` | 任务勾选、推荐顺序、文件列表 | 会话流水账 |
| `specs/<id>/design.md` | 技术方案、过渡态 | 产品愿景全文 |
| `handoff.md` §活跃 Spec | 多行索引：**状态**（与 VERSION 同枚举词）、下一步、blocker | 散文状态、大段设计/代码 |
| `handoff.md` §全局 Blocker | 跨 spec 部署/环境/依赖 | 单 spec 内任务 |
| `handoff.md` §最近触达 | **可选**；每 spec ≤5 行摘要；仓可无此节 | 替代 tasks.md |
| `planning/roadmap.md` | Gap → 版本一行（**唯一排期**） | 勿再建第二套排期目录 |
| `roadmap/weekly/` | **已停更**（历史只读） | 新排期 |

## Spec 状态枚举（VERSION = handoff 状态列）

唯一允许词：`draft` · `in-progress` · `review` · `done` · `archived` · `cancelled`

- **VERSION.md** `| **状态** |` 单元格只填一词（备注进变更记录）
- **handoff** 状态列与 VERSION **逐字相同**（CI 对账）
- `done` / `cancelled` → **当日** `git mv` 入 `specs/_archive/`，VERSION 改为 `archived`（cancelled 可保留）
- 活跃目录出现 `done`/`archived`/`cancelled` → CI **fail**（不再给 7 天宽限）
- 产品蓝图状态（`调研`…`归档`）只写 `product/README.md`，禁止写入 handoff/VERSION

## 并行规则

1. **允许多个** `in-progress` spec；开工时用户或 handoff 指明 **本次挂载的 `<id>`**；开工写 `specs/<id>/.claim`，收尾删除
2. 新功能 → `cp -r docs/specs/_template docs/specs/vYYYY.MM-<slug>/` → 在 handoff **加一行**，不删其他行
3. spec `done` → **当日**移入 `specs/_archive/`（VERSION→`archived`）+ handoff 行移入「最近关闭」
4. 无 spec 的筹备工作 → handoff「筹备中」表 + 链 `product/modules/`，**尽快切 spec**
5. **禁止**把 handoff 写成单一「当前焦点」长文（易锁死并行认知）
6. **WIP 上限**：**宿主约定**（默认建议 8；与宿主 docs 检查脚本 `WIP_CAP` 同一数字，若有）；超限先关版归档再开新版
7. **handoff 只做路由**：小修流水、历史验收段落**不进** handoff——归 `operations/` 或对应 `validation.md`

## 等人队列（blocked-on-human）

所有需要**用户本人**动作的事项集中一张表（审批 / 产品验收 / 生产窗口 / 真人角色测试 /
SSO 扫码 / 第三方登录），用户按此清账，agent 不重复催促。

**禁止入队**：Agent 可用本地密码登录或已知测试凭据完成的「换 Admin / 换成员」——那是
agent 待办，不是等人项（见 `vibe-coding` §身份切换）。

```markdown
## 等人队列

| 事项 | 所属 Spec | 需要什么 | 登记日期 |
|------|-----------|----------|----------|
```

## 开工路由

```
用户说「做 X」
  → handoff §活跃 Spec 找 <id>
  → 无 id → `spec` 或挂已有 spec 的 tasks.md
  → 读 specs/<id>/context.md + VERSION.md manifest
  → 忽略 handoff 里其他 spec 的「下一步」（除非用户明确要求并行）
```

## 收尾更新 handoff（必做）

只改与本会话相关的行：

- 更新对应 spec 的 **状态 / 下一步 / blocker**
- §最近触达：**可选**——仅当本仓 handoff 模板含该节时追加 `### <id> — YYYY-MM-DD`（≤5 行）；无该节则**跳过**
- **不要**整篇重写；**不要**把 tasks 全文搬进 handoff

## 仓库模板

各仓 `docs/reference/handoff.md` 应保持以下节标题（CI 可检查）：

```markdown
# 会话交接（Handoff）

最后更新：YYYY-MM-DD

## 活跃 Spec（可并行）

| Spec | 状态 | 下一步 | Blocker |
|------|------|--------|---------|
| [`vYYYY.MM-<slug>`](../specs/vYYYY.MM-<slug>/) | in-progress | … | — |

## 等人队列

| 事项 | 所属 Spec | 需要什么 | 登记日期 |
|------|-----------|----------|----------|

## 筹备中（尚未切 spec）

| 主题 | 设计稿 | 备注 |
|------|--------|------|

## 最近关闭

| Spec | 关闭日期 | 归档位置 |
|------|----------|----------|

## 全局 Blocker

（无）

## 最近触达（可选，每 spec ≤5 行）

### vYYYY.MM-<slug> — YYYY-MM-DD
- …
```

与 [`CONVENTIONS.md`](./CONVENTIONS.md) · [`vibe-coding`](../vibe-coding/SKILL.md) 一致。
