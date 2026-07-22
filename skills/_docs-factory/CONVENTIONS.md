# Docs Factory — 跨仓库约定（SDD Superpowers）

> 本文件随插件分发。技能真身在插件 `skills/`。宿主仓只保留 **`docs/` + `AGENTS.md`**。

## 0. Agent 主入口

| 场景 | Skill |
|------|-------|
| 「我希望…」未说开始做 | **`vibe-coding` Intake** → demand-pool / 塑形 |
| 「优化 / 改进」未说开始做 | **Intake** +（成块）**`product-design-package`** |
| 「排期 / 优先」 | **Owner** |
| 「开始做…」且切片已锁 | **Owner** → `spec` → **Build** |
| 编码开工 | **`vibe-coding`** |
| 切版 / 消歧 / 收敛 / 分析 / 质量 | **`spec`** |
| 测试 / 验收诚实度 | **`testing`** + [`VALIDATION-REPORT.md`](./VALIDATION-REPORT.md) |
| UX 定义 | [`UX-STANDARDS.md`](./UX-STANDARDS.md) + Spec Jobs |
| 产品包 | **`product-design-package`** |
| 产品回归 | `docs/product/foundation/product-regression.md` |
| docs CI | 宿主 `scripts/check-docs-sdd.sh` |

## 1. 仓库探测（禁止硬编码）

handoff → AGENTS → Spec VERSION/context → docs/README* → system-map → modules → rules。  
无骨架 → `scripts/scaffold.sh`。

## 2. 真源优先级

`specs/<id>/design + 代码` ≫ handoff 索引 ≫ `product/modules/` 蓝图。

## 3. 切版语义

默认 **A 忠实升格**；**B** 仅用户明示缩 scope。面向测试 / 体验见 `spec`。  
WIP 默认 8（与 `check-docs-sdd.sh` `WIP_CAP` 一致）。

## 4. 流水线

wish → ground → clarify/shape → lock → spec → build → verify → demo → deliver → observe → learn

## 5. 技能位置

插件 `skills/`；**禁止**宿主仓维护 skill 副本。

## 6. 回填

按宿主 `docs/README*`；未回填禁报完成（规则 `04`）。
