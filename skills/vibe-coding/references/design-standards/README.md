# Design Standards Pack（社区设计规范包）

插件预置的**默认可执行设计底线**：系统架构、UX、视觉、有 UI 时的页面门控。用户不必复述；Agent 按 Rail
默认加载。宿主品牌与栈例外写在 `AGENTS.md`，本版差量写在 Spec。

## 册

| 文件 | 内容 |
|---|---|
| [system-architecture.md](./system-architecture.md) | 分层边界、C4、ADR、坏味道、外部集成与性能通则 |
| [ux.md](./ux.md) | ISO 9241、Nielsen、体验检查面与反模式 |
| [visual.md](./visual.md) | 灰度优先、状态可见、WCAG 子集、防 AI 默认味 |
| [ui-page-gate.md](./ui-page-gate.md) | 有 UI：五问 → IA → 评审确认 → 再写页面 |

## 覆盖顺序（冲突时）

```text
本版 Spec（plan.md / tests.md / contract.md）
  ≫ 宿主 AGENTS.md（架构与体验/视觉例外）
  ≫ 宿主 docs/architecture/（若存在，as-built 边界）
  ≫ 本规范包默认
```

未经代码 / Schema / 配置 / 运行证据验证的架构或体验判断标 `Unverified`；仅 `Verified` 进 Lock / P0。

## 按 Rail 加载（默认执行）

| Rail | 必读 | 作用 |
|---|---|---|
| Shape（`design`） | `ux`；有 UI 时加 `visual`；讨论具体页面时加 `ui-page-gate` | 产品包自检；页面定位与 IA 可进理解卡 |
| Plan（`spec`） | `system-architecture`；有 UI 时加 `ux`+`visual`+`ui-page-gate` | `plan.md` 架构与设计边界轻门 |
| Build | AGENTS + 本版 `plan.md`；**写新页面 UI 前**执行 `ui-page-gate` | 确认前不写页面业务码；视觉服从 `visual` |
| Verify（`testing`） | 经 [ux-standards.md](../../../testing/references/ux-standards.md) 指向 `ux`；有 UI 加 `visual` | 与设计时同一套标准验收 / 走查 |

纯后端 / 无 UI：Shape/Plan/Verify 可跳过 `visual`、`ui-page-gate` 与 UX Job 验收；`run.md` 写 `UX: N/A` + 理由。

## 明确不做

- 不新建独立 Architecture / Design Rail；
- 不在 `templates/docs` 复制本包正文；
- 不预置完整 Material / HIG / 某云参考架构全文；
- 不把宿主品牌皮肤或栈组件 API 写进本包。

## 机读清单（Plan / 有 UI）

| 文件 | 用途 |
|---|---|
| [plan-architecture.checklist.json](./plan-architecture.checklist.json) | `plan.md`「架构与设计边界」子弹 |
| [ui-surface.checklist.json](./ui-surface.checklist.json) | 有 UI 时体验/视觉/门控自检 |

由 [`skills/spec/scripts/check_spec.py`](../../../spec/scripts/check_spec.py) 在 Plan→Build 门强制检查。

## 与产品包 / Spec

- 产品决策：`docs/product/modules/`（见 `product-package.md`）
- 本版实施：`docs/specs/<id>/`
- 站立 as-built 边界（可选）：宿主 `docs/architecture/`（scaffold full 可生成槽位）
