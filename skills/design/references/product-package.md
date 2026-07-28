# 产品包章节合同与剪枝

> 统一 `docs/product/modules/<slug>/` 层内写法。建包 → skill `design`。  
> 旧包不强制回填；新写/大改某层时对齐本合同。  
> 宿主模板不复制本文；仅 skills 为真源。

## 1. 骨架

```text
docs/product/modules/<slug>/
├── README.md
├── 01-experience.md
├── 02-product-model.md
├── 03-presentation.md   # 可同号改名
├── 04-runtime.md        # 薄：产品级约束
└── 05-delivery.md
```

读序钉死：体验 → 模型 → 呈现 → 运行时意图 → 交付。  
语言后缀随宿主约定（默认无后缀）。域特化只许同号改名。

## 2. modules ↔ specs（真源）

| 真源 | 写什么 | 本层边界外 |
|------|--------|----------|
| `modules/<slug>/` | 产品决策（可超前） | 本版实现细节、关版 Test 全文 |
| `specs/<id>/` | 本版实施 + `tests.md` 阅卷 | 只改 Spec 不改产品语义 |
| system-map + 代码 | as-built | 愿景蓝图 |

**05** 索引 Spec `T-xxx`；Test / Oracle 正文只在 Spec `tests.md`。

## 3. 全集章节（适用则写；否则 N/A+理由或省略整层）

### README
一句话 + 状态/Gap/Spec · 读序地图 · 已拍板决策**索引** · 真源边界

### 01 体验
设计立场 · 角色/画像 · 操控面 · 用户旅程 · 可感配置/屏幕 · 体验非目标  
（有 UI 时对照插件 [`design-standards/ux.md`](../../vibe-coding/references/design-standards/ux.md) 自检）

### 02 产品模型
能力表 · 概念术语 · 核心对象与状态 · 权限/触发 · 冻结项 · 非目标

### 03 呈现
IA · 文案/视觉语义 · 组件/表面规格（无 UI → 整篇省略）  
（对照 [`design-standards/visual.md`](../../vibe-coding/references/design-standards/visual.md)；品牌/DS 例外在 AGENTS）

### 04 运行时意图（薄）
进程/边界意图 · 关键路径语义 · 安全/观测约束  
表结构、长锚点、API 字段全集 → Spec `plan.md`

### 05 交付
分期 · 配置/环境 · 联调检查 · 风险 · 关版 Test **索引**（正文在 Spec `tests.md`）

## 4. 剪枝表

| 类型 | 剪枝 |
|------|------|
| 纯后端 / 无 UI | 省略 03 |
| 纯体验愿景 | 可省略 04（README 声明） |
| 单层 ≤~80 行 | 单文件豁免 |
| 域特化呈现 | `03-cards` / `03-authoring` 等同号 |
| 调研附录 | `05-research` / `06-*` 不占 01–05 合同位 |

**硬门：** 04 概念保留在 04；交付不改号接到 03；关版以 Spec 验收为准（设计稿单独不构成关版）。

## 5. 新包自检

- [ ] README 地图与真源边界齐全  
- [ ] 适用层含合同章节或 N/A+理由；空层已省略  
- [ ] 04 只有产品级约束  
- [ ] 关版 Test 以 Spec `tests.md` 为阅卷真源；05 只索引  
- [ ] 有 UI 时 01/03 已对照 design-standards ux/visual（或 N/A+理由）  
