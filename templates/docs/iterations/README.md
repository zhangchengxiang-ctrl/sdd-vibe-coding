---
title: 迭代（Iterations）
type: reference
status: active
owner: <谁>
updated: YYYY-MM-DD
---

# 迭代（Iterations）

层级：`product（做什么）→ 缺口 / 路线图（先做哪些）→ 版本 / 迭代（这一轮要达成什么）→ spec（从版本拆出的工作上下文包，放在版本目录里）`。

一个版本（迭代）就是一次许愿的完整上下文：先有用户原话（`quote.md`），推出需求（`requirements.md`），用户对待裁定项拍板（`decisions.md`），然后才切成 Spec。它回答 Spec 回答不了的事：为什么做这一轮、需求和裁定是什么、含哪些 Spec 且谁依赖谁、跨 Spec 的事项（请求单、复测窗口）、什么时候算关。

## 索引

| 迭代 | 目标 | 状态 |
|---|---|---|
| | | |

## 目录约定

```text
iterations/<yyyy-mm>/<w>/<版本>/
  quote.md         用户原话（逐字，最高优先级，只追加）
  requirements.md  本轮需求：判据（标出处）、范围、待裁定
  decisions.md     用户裁定与版本级决策（含豁免、放弃、Spec 移入移出）
  README.md     头部 type: iteration；目标、成功指标、Spec 清单与并行矩阵、关闭条件、当前阻塞
  baseline.md   基线、目标、复测口径与窗口
  release.md    发版与生产验证记录（只链接各 Spec 的 run.md，不复制）
  retro.md      关闭后复盘
  <spec-id>/    本轮拆出的 Spec（五件套，模板见 specs/_template/）
```

`<yyyy-mm>` 是版本开始的月份，`<w>` 是开始那周在当月的序号（`w1`～`w5`，周一起算）；路径从版本开始就固定，跨周跨月也不搬。工具不依赖这两层的写法：`iterations/` 下 README 头部为 `type: iteration` 的目录就是版本，其下含 `VERSION.md` 的子目录就是 Spec。

新建版本：复制 [`_template/`](./_template/README.md) 到 `iterations/<yyyy-mm>/<w>/<版本>/`，并在上表加一行。**只有一个 Spec 的小改动也建版本**（Spec 总是从某个版本拆出来的）。

## 三条硬规则

1. **状态只有一个真源**：迭代文档里的 Spec 表只放链接、触及路径、依赖、车道，**不抄 Spec 状态**；状态以各 Spec 的 `VERSION.md` 与 `run.md` 为准。
2. **目录即归属**：Spec 建在版本目录下，不再写 `iteration:` 字段。一个 Spec 只属于一个版本；改到下一轮就把 Spec 目录 `git mv` 到新版本下，并在两边的 `decisions.md` 各记一行。
3. **关闭条件可检查**：所有成员 Spec 为 `archived`（`close-spec` 关版）或 `cancelled`（理由记入 `decisions.md`），`retro.md` 已写，基线复测完成或由 owner 明示豁免；然后 `close-iteration` 把版本 README 状态改为 `archived`。前两条由 `close-iteration` 机检。关闭不搬目录。

## 并行矩阵怎么填

每个成员 Spec 一行：**触及路径**（取自 `plan.md` 切片表的 `触及路径` 列，写 `文件` 或 `文件::符号`）、依赖、车道。

- 触及路径不相交，且不共享迁移、公共 API、生成物 → 可同时派发；
- 同一文件被 ≥ 3 个切片修改 → 热点，进同一串行车道，或先开拆文件的前置 Spec；
- 触及路径是预估而非实测的，要在该格标明。
