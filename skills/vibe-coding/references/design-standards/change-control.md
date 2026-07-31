# UI change control（Refine / Redesign · Material decision）

> 蒸馏：Impeccable How-to-design、Vercel teaching-agents「material decision」。  
> 改已有界面前先分叉；禁止「半 polish 半换皮」。

## 1. Refinement vs Redesign

| 分叉 | 保留 | 替换 | 禁 |
|------|------|------|-----|
| **Refinement** | 身份、行为、文案体系、导航心智 | 对齐、间距、状态、局部 token、可达性 | 偷偷换整套视觉世界 |
| **Redesign** | 产品真值（Job、数据、权限） | **整套**视觉语言（旧 look 作**反参考**） | 只改几处颜色却宣称 Redesign |

开改前声明一行：`change: refinement | redesign`。  
用户未说「重做视觉 / 换皮」→ 默认 **refinement**。

## 2. Material decision 门

改 UI 前判断是否 **material**（会影响任务、默认、后果、导航或可达状态）：

| Material（升格 Shape/Plan 或写进 Spec） | 通常非 material（可局部修） |
|----------------------------------------|------------------------------|
| 改主任务路径 / 入口 / 权限可见性 | 文案用词微调（不改承诺） |
| 改默认筛选、排序、空态主 CTA | token 对齐、错缝、对比度 |
| 新增/删除导航目标或破坏性后果 | 纯装饰删除、a11y 补 label |
| 换 shell / visitor_mode / 大面积 IA | 单控件 hover/focus 补全 |

非 material → 不必新开 Spec；仍走 LOAD-MAP 相关册 + ai-tells。  
Material → 更新切片或 Spec 字段后再 Build。

## 3. Finding 分级（走查/自扫）

| 级 | 含义 | 处置 | 与 Nielsen |
|----|------|------|------------|
| P0 | 挡 Job / 无障碍致命 / 数据谎言 | 必须修再关版 | **严重度 4** |
| P1 | 主路径摩擦、状态缺失、合同违反 | 本批修 | **严重度 3** |
| P2 | 偏好、抛光 | 可记后续 | **严重度 1–2** |

映射真源：本表 ↔ [ux.md](./ux.md) 严重度 0–4。Verify 交付卡可用任一套，勿混用无映射。

## 4. 自检

- [ ] 已声明 refinement 或 redesign  
- [ ] material 变更已进合同；非 material 未假装大改  
- [ ] 无「半套新皮肤」  
