# Shape：代码库 grounding（只读拆解）

当 Shape 需要从**现有代码**或**参考仓库**建立事实时使用；不是独立 Rail。
默认只读代码；写入 `docs/product/` 须用户确认。不满足写码硬闸时禁止改业务代码。

## 何时启用

- 用户说：拆解 / deconstruct / 学习这个 repo / 分析这个项目
- 宿主产品文档空或明显落后于代码，Shape 必须先对齐 as-built
- 研究外部参考实现，准备回填本仓能力 / gap
- **存量首次接入 SDD**（已有 `docs/` / wiki，刚 scaffold）：走下方 Brownfield bootstrap

## 探测（禁止写死路径）

Glob / Read：`AGENTS.md` · `docs/product/` · `docs/_host/` · openapi · `apps|backend|frontend|src`

上下文打包优先：本地 Repomix → Gitingest → 原生 README / 路由 / Service / Grep。私有仓不上传外部 SaaS。

## Brownfield bootstrap（存量首轮）

1. 确认已 `scaffold`（`minimal`/`detect`；冲突可用 `--root=docs/sdd`）；有 `BLOCK` 先处理。
2. 读 `AGENTS.md` 的 **SDD docs root**（缺省 `docs`）；其后 `docs/product` 均相对该根。
3. 盘点已有文档（宿主 `docs/**`、顶层 README、外部 wiki）→ 产出**链接表**；**默认不整页搬进** product。
4. 填 `AGENTS.md` 中可核验的命令 / URL / 就绪度（空槽才写）。
5. 用户确认后：只回填**当前切片相关**的 `modules/<slug>/` 与 `gap-register` 必要行；禁止为「整齐」批量空建 `foundation/` 全套。

## 必做产出（草稿，确认后落盘）

1. **Product 回填**：能力域、Must、可观察验收、关联旅程 → 对齐 `docs/product/` / `modules/<slug>/`（优先链接旧文档）
2. **Gap**：相对 product 期望缺失或明显偏弱的项 → `gap-register`（或宿主等价）草稿；不切 Spec
3. **可选**：arc42 向 as-built 笔记；外部借鉴时的 BORROW 决策草稿（宿主约定路径）

Greenfield：未实现的 Must = open Gap。拆解自身时可提议更新 `system-map.md`。

## 下游

grounding 完成后继续本 Skill 的 Shape（理解卡 / 决策卡 / 产品包）。升格实施仍走闸门 → Plan（`spec`）。
