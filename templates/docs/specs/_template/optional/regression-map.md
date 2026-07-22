# Regression Map · <surface-or-spec-title>

> **产品回归地图**（长期可跑子集）。合同：[`docs/product/foundation/product-regression.md`](../../../product/foundation/product-regression.md)  
> 关版后登记 [`docs/product/regression-register.md`](../../../product/regression-register.md)；正文留 Spec / `_archive`（方案 A，勿拷 modules）。

**范围：** （从 scenario-spec 晋升的关键旅程）  
**Out：** （不挡绿；可链 GAP）  
**入口：** 宿主 `AGENTS.md` 中的 verify-spec / product-regression 命令

## 分层

| 层 | 证明什么 | 命令 / 手段 |
|----|----------|-------------|
| contract | 合同预检 | |
| product | 真浏览器用户主路径 | |
| manual | 人工 | （不挡自动绿） |

## SC 覆盖表

| SC | 旅程 | 层 | 证据 | 状态 |
|----|------|-----|------|------|
| SC-n | | contract / product / manual | | 回归 · Out |

## 维护

- 先改本表，再改测试标题（须含 `SC-N`）  
- Out 禁止假 Pass  
- 晋升后更新 `regression-register` + `surfaces.json`
