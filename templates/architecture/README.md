# Architecture（可选站立真源）

> 产品决策在 SDD `product/`；本版实施在 `specs/`；**跨 Spec 的 as-built 边界与 ADR** 可放本目录。  
> 默认可执行原则在插件 `skills/vibe-coding/references/design-standards/`；此处只记宿主事实与决策。  
> 覆盖顺序见该包 README。

## 文件

| 文件 | 写什么 |
|---|---|
| [boundaries.md](./boundaries.md) | 分层、依赖方向、写入边界、模块 README 约定 |
| `adr/`（自建） | 架构决策记录（何时必写见插件 system-architecture.md） |

C4 L1/L2 图可用 Mermaid 写在 `boundaries.md` 或独立 `c4-*.md`。

## 不写什么

- 不复制插件 design-standards 长文；
- 不双写产品包体验文案；
- 不把本版临时差量当站立真源（差量在 Spec `plan.md`）。
