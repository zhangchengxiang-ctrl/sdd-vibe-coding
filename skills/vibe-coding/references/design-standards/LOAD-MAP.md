# LOAD-MAP（任务 → 必读）

> **有 UI 施工时先读本表再开写。** 不读本表 = 未执行 design-standards。  
> 路径均相对 `skills/vibe-coding/references/design-standards/`。  
> **字段×Rail 强度、豁免、场景必读：只以本文件为准**；其它册/Skill 只链到这里，勿另写强度表。

## 字段门控（唯一真源）

| 字段 | Shape | Plan（`check_spec`） | Build |
|------|-------|----------------------|-------|
| **Job Brief**（见 [product-judgment.md](./product-judgment.md)） | **必须**（有 UI） | **warn** 若缺 | **必须** |
| `UI surface` | **必须** | **fail** 若缺 | **必须** |
| Design Read | **必须**（有 UI） | **warn** 若缺 | **必须** |
| `page_kind` 或 `motif` | 有具体页则必须 | **warn** 若缺（二者等价） | **必须** |
| `anchor` + `diverge` | 可后置到切片收敛 | **warn**（Build 前须补） | **必须** |
| knobs / `visitor_mode` | 建议 | 建议（缺则用 craft-knobs 默认） | 缺则用默认 |
| `shell`（product 改壳） | 建议 | **warn** 若疑改壳却未声明 | **必须** |
| `change: refinement\|redesign` | 改存量时声明 | 改存量时声明 | 改存量时 **必须** |

`motif:` 与 `page_kind:` **等价**（consumer 可写 `motif: growth` 或 `page_kind: growth`）。

**硬门（顺序）：**

1. Job Brief 三必填（Job / Desired outcome / Consequence）未齐 → **不得**定视觉、不得输出线框当定稿、不得写新页业务 UI（应先问清）。见 [product-judgment.md](./product-judgment.md)。  
2. 未声明 surface / 未写 Design Read → **不得定视觉方向、不得写新页业务 UI**。  
3. Build 前未写可用 anchor → **不得定视觉实现方向**（可先写 IA/文案结构）；见 [anchor.md](./anchor.md)。

## 豁免（缩读）

| 情形 | 仍须 | 可跳过 |
|------|------|--------|
| trivial：笔误 / 单点 CSS / 已知单控件 bug（不改合同·导航·跨面入口·权限可见性） | 相关控件册（如有）+ 输出前 [ai-tells](./audit/ai-tells.md) 抽一眼 | 完整前缀、Job Brief 重写、ui-page-gate、新 anchor |
| **Polish / 非 material refinement**（见 [change-control.md](./change-control.md) §3；须写码硬闸 (c)） | LOAD-MAP **场景行**相关册 + ai-tells；声明 `change: refinement`；沿用已有 Job Brief（无则从界面推断并标假设） | 新 Spec、完整产品包、完整页面评审、重写 Design Read / Job Brief、新 anchor |
| 已有 Spec 内的非 material UI 修补（Repair / 批内抛光） | 同上 + 对照既有 Job Brief | 新开另一份 Spec |

触及导航 / 跨表面入口 / 主任务路径 / shell / visitor_mode / **权限或分发模型** 大改 → **非豁免**，走完整前缀（含 Job Brief）；不得用 Polish 话术绕过。

## 每次有 UI 的固定前缀（非豁免）

0. **[product-judgment.md](./product-judgment.md)** — Job Brief + 人话验收；**IA / 交互单位先于视觉**  
1. [craft-knobs.md](./craft-knobs.md) — **Design Read** 一行；建议 visitor_mode + variance/motion/density  
2. [anchor.md](./anchor.md) — 写下 anchor / diverge（Shape 可后置；**Build 前必须**）  
3. 定 `UI surface` + `page_kind`/`motif` → [surfaces/README.md](./surfaces/README.md) · [pages/README.md](./pages/README.md)  
4. [tokens/](./tokens/)（有宿主 DS 则只遵角色与禁令）  
5. [audit/ai-tells.md](./audit/ai-tells.md) — **输出前再扫一遍**

改已有 UI 先读 [change-control.md](./change-control.md)。  
写页面前评审输出模板 → [ui-page-gate.md](./ui-page-gate.md)（加载义务仍以本表为准；评审块须含 Job Brief）。

## 按场景加读

| 你在做什么 | 必读（按序） |
|------------|--------------|
| 判定 B/C、写切片 | **product-judgment** → surfaces/README → product.md 或 consumer.md；craft-knobs |
| **配置 / 授权 / 分发 / 发布范围**（谁能用、怎么发、ACL、成员选择器） | **product-judgment**（人话验收+交互单位）→ copy（禁黑话）→ overlays → bulk-actions |
| 新建/改应用壳 | surfaces/product-shells.md |
| **列表页** | pages/list.md → components/product-datatable.md → product-forms-states（空态） |
| **详情页** | pages/detail.md → product-forms-states → overlays.md（预览用 Sheet） |
| **设置页** | **product-judgment** → pages/settings.md → product-forms-states → copy.md |
| **看板** | pages/dashboard.md → tokens/color-roles（chart）→ ai-tells |
| **整页/大表单** | **product-judgment** → pages/form.md → product-forms-states → product-primitives |
| Modal / Sheet / Drawer / 行内 | **先 product-judgment（交互单位）** → [components/overlays.md](./components/overlays.md)（只定容器） |
| Cmd+K / 命令面板 | components/command-palette.md |
| 批量选择/行动条 | **product-judgment** `rule/batch-same-search` → components/bulk-actions.md |
| 按钮/输入/Tag 尺度 | components/product-primitives.md 或 consumer-primitives.md |
| 控件 hover/focus/disabled | components/interaction-states.md |
| C 端主路径 | product-judgment → surfaces/consumer.md → pages/consumer.md → consumer-primitives |
| C 端落地 growth | surfaces/consumer.md「growth」→ pages/consumer.md → copy.md · craft-knobs |
| 文案/错误/空态措辞 | [copy.md](./copy.md) + product-judgment `rule/no-impl-jargon` |
| 焦点/表单 a11y 审计 | audit/web-interface.md |
| UI 回归 / 错缝 / AI 脸 | [debug-playbook.md](./debug-playbook.md) |
| 对照好坏 | [exemplars/](./exemplars/README.md)（含 judgment） |

## 按 Rail（摘要；强度见上表）

| Rail | 动作 |
|------|------|
| Shape | **先 Job Brief**；写 Design Read；必须 surface；有具体页则 page_kind/motif；knobs 建议；anchor 可后置；读对应 surfaces |
| Plan | 合同写 Job Brief + surface；page_kind/motif + Design Read + anchor 建议（机检 warn）；架构边界点名服从本包 |
| Build | **Job Brief 齐全** + **本表场景行全文** + 需要时 ui-page-gate 评审模板；改存量先 change-control；确认前不写页 |
| Verify | 同 surface/page_kind；**先证伪**（testing/falsify-checklist）；对照人话验收 / Job；ai-tells + web-interface + copy 抽检；有界轮次见 testing/bounded-verify；list/dashboard 须 api-diff/network-har |

## 禁止

- 跳过 product-judgment / Job Brief，直接 overlays 或 tokens 开画  
- 只读 [visual.md](./visual.md) / [ux.md](./ux.md) 开头就开写（二者是原则索引，非施工入口）  
- 跳过 Design Read / surface 用「现代干净」代替  
- Build 前跳过 anchor 用空话形容  
- 列表不读 datatable、详情不读 detail、弹层不读 overlays  
- UI/验收使用实现黑话（主体、投影未完成、registry…）冒充产品语言  
