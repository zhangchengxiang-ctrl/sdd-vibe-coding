---
name: product-design-package
description: >-
  SDD 产品塑形与分层蓝图：体验 / 模型 / 呈现 / 运行时 / 交付。
  触发：写产品设计 / product/modules / 优化体验 / 改 IA·导航·入口 /
  成块 UX 愿望（未说开始做时勿改业务代码）。
---

# 产品设计包（Product Design Package）

**方法论：** 关注点分层产品包。  
**章节合同真源：** 宿主 `docs/product/foundation/product-package-contract.md`（若无则用插件 templates 骨架）。  
**互补：** `vibe-coding` · `spec` · [`_docs-factory/CONVENTIONS.md`](../_docs-factory/CONVENTIONS.md)

**DO NOT CODE**：本 skill 只 Shape / 蓝图。确认实施后回 `vibe-coding` → 体系调 `spec`。  
默认 **Intake**：可写 `modules/` + 需求池；**禁止**升格 Spec 或改业务代码。

---

## 0. 何时用

| 场景 | 动作 |
|------|------|
| 「我希望…」 | 一屏 Wish；勿立刻五层全文 |
| 「优化 / 改进」成块体验（IA、导航、入口、发布模型） | **开/改包**；禁止「清单够清楚 → 改码」 |
| 新功能蓝图（非 trivial） | **默认建包** |
| 多篇横切同一能力 | **合并进一包** |
| 单篇混多层 | **按层拆开** |

**与 Build 闸门**：编号清单 + 截图仍是 Wish；未说「开始做 / 实现 / 按这个来」→ 只写 `modules/`（+ 可选 DEM）。

### 豁免（可单文件）

同时：正文 ≤ ~80 行 · 只覆盖一层 · 无多层混写。索引在 `docs/product/README.md` 备注「单文件 · 豁免」。

### 愿望渐进塑形

```markdown
目标：
当前系统状态：
建议的首个价值切片：
关键假设：
Delivery Target：
需要决定的问题：
```

先内部 Ground；互斥方向 / 单向门 / 显著成本才问产品专家。外部调研门：竞品/法规/最新平台事实不足时再联网。

---

## 1. 目录

```text
docs/product/modules/<slug>/
├── README.md              # 门面（必）
├── 01-experience.md       # 体验（默认必）
├── 02-product-model.md    # 产品模型（默认必）
├── 03-presentation.md     # 呈现（可省）
├── 04-runtime.md          # 运行时意图·薄（可省）
└── 05-delivery.md         # 交付（默认必）
```

| 规则 | 说明 |
|------|------|
| `<slug>` | kebab-case；能力名非版本号 |
| 编号 | `01`–`05` 固定读序；域特化可同号改名，须在 README 声明 |
| 语言后缀 | **读宿主约定**（默认无后缀 `.md`；宿主可要求 `.zh-CN.md` 等） |
| 空层 | README 声明省略，勿造空文件 |

---

## 2. 五层职责

| 序 | 文件 | 负责 | 不负责 |
|----|------|------|--------|
| — | README | 一句话、状态、读序、决策索引 | 展开规则正文 |
| 1 | 01-experience | 角色、旅程、操控面、体验非目标 | 表结构、算法细节 |
| 2 | 02-product-model | 能力、对象、状态、权限、冻结项 | UI JSON、实现路径 |
| 3 | 03-presentation | IA、文案/视觉语义、表面规格 | 业务触发、DB |
| 4 | 04-runtime | **薄意图**：边界、关键路径语义 | 表结构、API 全集 → Spec |
| 5 | 05-delivery | 分期、联调、风险；可**索引** SC | 重定义概念；SC 正文在 Spec |

层内章节全集 → 宿主 `product-package-contract`（无则 templates）。

---

## 3. README 门面（必含）

一句话 · 状态/Gap/Spec · 读序地图 · 已拍板决策**索引表** · 真源边界。决策只索引不复制规则。

---

## 4. 拆分 / 合并 SOP

定边界 → 标层 → 写包 → 删旧路径并改外链 → 更新 `docs/product/README.md` → 自检无双真源。

---

## 5. 与 Spec

| 层 | 角色 |
|----|------|
| `product/modules/<slug>/` | 产品决策蓝图（可超前） |
| `docs/specs/<id>/` | 本版实施 + 关版 scenario |
| system-map + 代码 | as-built |

「开始做」后由 `spec` 升格；切版必含 `scenario-spec` 覆盖矩阵（non-trivial）。  
**禁止** modules 与 Spec 双写关版 SC 正文。

---

## 6. 反模式

按渠道拆平行长文 · README 粘贴全文 · 凑五层空文件 · 拆包顺便改契约 · 04 写成实现手册 · 「清单清楚直接改码」。
