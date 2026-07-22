# Test Plan · <version-id>

## 自动化

| 范围 | 命令 | 通过标准 |
|------|------|----------|
| 定向静态检查 | `<与改动范围匹配的命令>` | 本次 diff 相关 0 error |
| 定向单元/集成 | `<相关测试文件或子集>` | 0 failed |
| 场景 E2E（若适用） | `npx playwright test tests/e2e/<spec>.spec.ts` | 0 failed |

全量 `make check` / `make test` / E2E 只在发布、CI、全局合同或用户明确
要求时加入本表；不要把所有可用命令默认叠加。

## 浏览器（若改 `<host-ui>/`）

| 场景 | 步骤 | URL |
|------|------|-----|
| | | （宿主 AGENTS.md 中的预览 URL）… |

遵循宿主 AGENTS.md 中的浏览器验收约定。

## 回归

- 若触达 [`docs/product/regression-register.md`](../../../product/regression-register.md) 中 `active` 面 → 跑该面「验证入口」（产品回归，非本版验收矩阵全文）。
- 本版关版且模块进入维护态 → 晋升关键子集到 Spec 根 `regression-map.md` 并登记（合同：`foundation/product-regression.md（若有）`）。
- [ ] 未登记面：至少自列 2–3 条未改核心路径仍可用（临时；有稳定子集后应晋升登记）

## 部署相关（若触达）

- [ ] `npm run db:migrate:pg` 成功（若改 schema）
- [ ] `/health` → `db.migrationStatus: "ready"`
- [ ] 目标 `宿主部署/reload 命令` 已执行
