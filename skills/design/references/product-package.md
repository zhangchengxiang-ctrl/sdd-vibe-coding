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
└── 04-runtime.md        # 薄：产品级约束
```

读序钉死：体验 → 模型 → 呈现 → 运行时意图。
产品包是**常青**文档（文档标准「三类文档」）：只写产品要做成什么样。分期、灰度、联调、风险与关版 Test 索引属于这一轮，写在版本目录（`README.md` 的 Spec 清单与并行矩阵、`requirements.md`）；系列验收矩阵写在版本目录的 `acceptance-matrix.md`（见 testing `version-acceptance-matrix`）。  
语言后缀随宿主约定（默认无后缀）。域特化只许同号改名。

## 2. modules ↔ specs（真源）

| 真源 | 写什么 | 本层边界外 |
|------|--------|----------|
| `modules/<slug>/` | 产品决策（可超前） | 本版实现细节、关版 Test 全文 |
| 版本目录 `iterations/<yyyy-mm>/<w>/<版本>/` | 这一轮：原话、需求、裁定、分期、系列验收 | 产品语义变化写回本层 |
| Spec `iterations/<yyyy-mm>/<w>/<版本>/<id>/` | 本版实施 + `tests.md` 阅卷 | 只改 Spec 不改产品语义 |
| system-map + 代码 | as-built | 愿景蓝图 |

Test / Oracle 正文只在 Spec `tests.md`；产品包不索引 `T-xxx`（那是版本与 Spec 的事）。

## 3. 全集章节（适用则写；否则 N/A+理由或省略整层）

### README
一句话 + 所属版本 / Gap 的链接（不写状态） · 读序地图 · 已拍板决策**索引** · 真源边界

### 01 体验
设计立场 · 角色/画像 · 操控面 · 用户旅程 · 可感配置/屏幕 · 体验非目标  
（有 UI 时按 [`LOAD-MAP`](../../vibe-coding/references/design-standards/LOAD-MAP.md) 场景自检；启发式见 [`ux.md`](../../vibe-coding/references/design-standards/ux.md)）

### 02 产品模型
能力表 · 概念术语 · 核心对象与状态 · 权限/触发 · 冻结项 · 非目标

### 03 呈现
IA · 文案/视觉语义 · 组件/表面规格（无 UI → 整篇省略）  
（有 UI → [`LOAD-MAP`](../../vibe-coding/references/design-standards/LOAD-MAP.md)；原则索引 [`visual.md`](../../vibe-coding/references/design-standards/visual.md)；品牌/DS 例外在 AGENTS）

### 04 运行时意图（薄）
进程/边界意图 · 关键路径语义 · 安全/观测约束  
表结构、长锚点、API 字段全集 → Spec `plan.md`

## 4. 剪枝表

| 类型 | 剪枝 |
|------|------|
| 纯后端 / 无 UI | 省略 03 |
| 纯体验愿景 | 可省略 04（README 声明） |
| 单层 ≤~80 行 | 单文件豁免 |
| 域特化呈现 | `03-cards` / `03-authoring` 等同号 |
| 调研附录 | 调研结论是记录，放 `reports/`（带日期），不进产品包 |

**硬门：** 04 概念保留在 04；交付不改号接到 03；关版以 Spec 验收为准（设计稿单独不构成关版）。

## 5. 新包自检（换靶：可感主路径，非齐套）

- [ ] **可感主路径卡**在（谁 / 触发 / 第一次成功结果 / 怎么观察到）——见 [`perceptible-path.md`](./perceptible-path.md)  
- [ ] 「怎么观察到」**未**命中 [`scheme-antipatterns.md`](./scheme-antipatterns.md)  
- [ ] 空层已省略（不为齐套建空文件）；简单诉求可用单页 / demand，不强制五层  

~~章节齐全勾选表已删除（齐套 ≠ 质量）。~~
