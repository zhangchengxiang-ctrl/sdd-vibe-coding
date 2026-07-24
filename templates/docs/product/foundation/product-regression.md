# 产品回归（Product Regression）· 通用合同

> **证明什么：** 用户今天仍能办成的关键事，在改码后没有回退。  
> **真源原则：** 产品回归 = **真浏览器 + 真登录跑通用户主路径**（宿主可规定登录方式），长期、可累积、可选型。  
> **禁止：** 用单测 / mock / 伪登录 / 空态浅 Pass 冒充产品回归 PASS。

活索引：[`../regression-register.md`](../regression-register.md) · 机读：[`../regression/surfaces.json`](../regression/surfaces.json)

**验收自检：** 若某条「产品回归 PASS」可以在**不打开真实 UI、不按用户点路径**的情况下成立 → 不合格。

---

## 0. 与相邻概念

| 概念 | 证明什么 | 真源 |
|------|----------|------|
| **验收** | 本版相对设计能否办成 | Spec `scenario-spec` + Browser 证据 |
| **Repair 后再测** | 同根因 implementation Fail 是否修好 | Repair 执行步骤 的 Scenario 与 evidence |
| **产品回归** | 维护态：同一批用户主路径是否仍成立 | register 选型复跑 **同级** 浏览器证明 |

---

## 1. 三层证明（勿混称）

| 层 | 字段 | 载荷 | 可声称 | 不可声称 |
|----|------|------|--------|----------|
| **contract** | `verify_contract[]` | 合同 / 预检单测 | 「合同层绿」 | 「产品回归 PASS」 |
| **product** | `verify_product[]`（`proof: product`） | 真浏览器 + 登录 + 用户主路径 | **「产品回归 PASS」** | — |
| **manual** | `manual` / `manual_scenarios[]` | 真机 / 人工剧本 | 证据补充 | 不挡自动；**永不自动 PASS** |

**铁律：**

- 面 `proof: product` 但 `verify_product` 为空 → 检查脚本**非零退出**
- 只跑 contract → 只能写 `[合同层·…·绿]`，禁止写产品回归完成
- `product` 层命令必须是真浏览器用户路径；把单测塞进 `verify_product` = 违规

---

## 2. 覆盖模型（角色 × 旅程）

每个 product 面在 `surfaces.json` 声明：

| 字段 | 含义 |
|------|------|
| `roles[]` | 已自动化覆盖的产品角色（宿主自定义编码） |
| `journeys[]` | 已覆盖主旅程（可注源 SC） |
| `coverage_source` | 目标覆盖矩阵所在 Spec |
| `manual_scenarios[]` / `coverage_backlog[]` | 尚未自动化的诚实缺口 |

声称「全覆盖」= `roles × journeys` 对齐 `coverage_source`；缺口只能进 backlog。

---

## 3. 累积（只增不降）

1. 功能 Spec 验收 **Pass** 的浏览器用户主路径 → **必须晋升**进对应面 `verify_product`
2. **禁止降级**：Browser Pass → 只留单测；办成事 → 「按钮可见」
3. 未自动化的 manual Pass → 记 backlog，作后续自动化目标
4. 删除/弱化已有 `verify_product` = 违规（除非能力下线并登记退役）

---

## 4. 何时跑（选型 · 禁默认全库）

| 时机 | 跑什么 |
|------|--------|
| diff 命中 `touch` | 命中面的 contract + product |
| 单面 / 模块 | `SURFACE=` / `MODULE=`（宿主命令） |
| 全库 | 宿主显式全量参数（非默认） |
| 仅合同探活 | 显式 contract profile（不得称产品 PASS） |

选型命令以宿主 `AGENTS.md` 为准。

---

## 5. 范围标签

报告必带：`[产品回归·浏览器·…]` / `[合同层·…]` / `[人工待跑·…]` / `[缺产品层·…·FAIL]`。

---

## 6. 禁止

- 用「会绿的单测」替代 Spec 浏览器用例
- 伪登录 / 空态浅 Pass 当产品绿
- 文档齐了就报「产品回归已落地」而载荷弱于来源 Spec
- 默认只跑 contract 就报产品回归完成

## 7. 工件

| 工件 | 路径 |
|------|------|
| 合同 | 本文件 |
| 人读 | `docs/product/regression-register.md` |
| 机读 | `docs/product/regression/surfaces.json` |
| Spec 地图 | `docs/specs/<id>/regression-map.md` 或 `_archive/…`（正文不搬 modules） |
