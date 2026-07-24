# Shape：代码库 grounding（只读拆解）

当 Shape 需要从**现有代码**或**参考仓库**建立事实时使用；不是独立 Rail。
默认只读代码；写入 `docs/product/` 须用户确认。不满足写码硬闸时禁止改业务代码。

## 何时启用

- 用户说：拆解 / deconstruct / 学习这个 repo / 分析这个项目
- 宿主产品文档空或明显落后于代码，Shape 必须先对齐 as-built
- 研究外部参考实现，准备回填本仓能力 / gap

## 探测（禁止写死路径）

Glob / Read：`AGENTS.md` · `docs/product/` · openapi · `apps|backend|frontend|src`

上下文打包优先：本地 Repomix → Gitingest → 原生 README / 路由 / Service / Grep。私有仓不上传外部 SaaS。

## 必做产出（草稿，确认后落盘）

1. **Product 回填**：能力域、Must、可观察验收、关联旅程 → 对齐 `docs/product/` / `modules/<slug>/`
2. **Gap**：相对 product 期望缺失或明显偏弱的项 → `gap-register`（或宿主等价）草稿；不切 Spec
3. **可选**：arc42 向 as-built 笔记；外部借鉴时的 BORROW 决策草稿（宿主约定路径）

Greenfield：未实现的 Must = open Gap。拆解自身时可提议更新 `system-map.md`。

## 下游

grounding 完成后继续本 Skill 的 Shape（理解卡 / 决策卡 / 产品包）。升格实施仍走闸门 → Plan（`spec`）。
