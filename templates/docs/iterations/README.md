---
title: 迭代（Iterations）
type: reference
status: active
owner: <谁>
updated: YYYY-MM-DD
---

# 迭代（Iterations）

层级：`product（做什么）→ 缺口 / 路线图（先做哪些）→ 迭代（这一轮要达成什么）→ spec（一个可验收切片）`。

一个迭代回答 Spec 回答不了的四件事：为什么做这一轮、含哪些 Spec 且谁依赖谁、跨 Spec 的事项（请求单、owner 决策、复测窗口）、什么时候算关。

## 索引

| 迭代 | 目标 | 状态 |
|---|---|---|
| | | |

## 目录约定

```text
iterations/<slug>-<YYYY.MM>/
  README.md     目标、成功指标、Spec 清单与并行矩阵、关闭条件、当前阻塞
  baseline.md   基线、目标、复测口径与窗口
  decisions.md  迭代级决策与 owner 裁决（含豁免与放弃）
  release.md    发版与生产验证记录（只链接各 Spec 的 run.md，不复制）
  retro.md      关闭后复盘
```

新建迭代：复制 [`_template/`](./_template/README.md)，并在上表加一行。只有一个 Spec 的小改动不需要迭代。

## 三条硬规则

1. **状态只有一个真源**：迭代文档里的 Spec 表只放链接、触及路径、依赖、车道，**不抄 Spec 状态**；状态以各 Spec 的 `VERSION.md` 与 `run.md` 为准。
2. **Spec 反向标注归属**：`VERSION.md` 可选字段 `iteration: <slug>`；未支持该字段的存量 Spec，以迭代文档的清单为准。
3. **关闭条件可检查**：所有成员 Spec 为 `acceptance-passed` 或明确放弃，且基线复测完成；豁免复测须由 owner 明示并记入 `decisions.md`。

## 并行矩阵怎么填

每个成员 Spec 一行：**触及路径**（取自 `plan.md` 切片表的 `触及路径` 列，写 `文件` 或 `文件::符号`）、依赖、车道。

- 触及路径不相交，且不共享迁移、公共 API、生成物 → 可同时派发；
- 同一文件被 ≥ 3 个切片修改 → 热点，进同一串行车道，或先开拆文件的前置 Spec；
- 触及路径是预估而非实测的，要在该格标明。
