# Validation · <version-id>

> 只记录本版实际运行的证据。未选择的验证写 N/A + 理由，不为填表补跑全量命令。

## 直接验收条件

- [ ] 当前交付范围的 AC（见 requirements.md）已满足
- [ ] 当前 Slice 对应 Scenario 无未清差异

## SC 交付追踪链

| SC | 用户结果 | 实现位置 | 正确性证据 | 环境证据 | 体验判决 | 交付状态 |
|----|----------|----------|------------|----------|----------|----------|
| SC-1 | | | | | | `code-ready / dev-effective / production-delivered / user-accepted` |

任一列没有证据时，只能声明已达到对应的较低 Delivery Target。

## 定向验证

| 证据层 | 实际命令 / 步骤 | 结果 | 说明 |
|--------|-----------------|------|------|
| V0 diff / 静态 | | | |
| V1 单元 / 集成 | | | |
| V2 Scenario / Browser | | | |
| V3 全量回归 | N/A | | 仅发布、CI、全局合同或用户明确要求 |

- [ ] 若改 DB：迁移命令与 `/health`（或仓内等价）通过

## 浏览器（若改 `<host-ui>/`）

- [ ] 遵循宿主 AGENTS.md 中的浏览器验收约定
- [ ] 目标 URL 非 Not Found / 白屏
- [ ] 关键且稳定的新旅程按需补永久 E2E

## 场景验收

- [ ] 当前交付范围内非 N/A 的 Scenario 已执行；未实施后续 Phase 不提前验收

## 独立审查（按风险）

| 判定 | 结果 |
|------|------|
| 低风险 | N/A；Parent diff 自检 |
| 单向门 / 高风险 | 一次只读人审结果，或 N/A |
| 用户产品确认 | Spec 明确要求时填写，否则 N/A |

## Delivery Gate

- **声明目标**：
- **实际达到**：
- **环境 / 版本**：
- **reload / deploy**：
- **migration / health**：
- **交付后关键路径**：
- **回滚点**：
- **Observe 结果 / 用户反馈**：

## 文档回填（按适用项）

- [ ] **文档 DoD**：
  - [ ] 改 deploy 单元 / 进程红线 → `product/foundation/system-map.md`
  - [ ] 实现细节 → **以代码 + 本版 `design.md` 为准**（勿再写独立 architecture 运行时长文）
  - [ ] 改部署 → 宿主生产/发版 guide · `AGENTS.md`
  - [ ] 不可逆决策 → `product/decisions/NNN-*.md`
  - [ ] 新差距 → `product/gap-register.md`
- [ ] **Docs 回填**（路径或 **Docs: N/A** + 理由）：
  - [ ] `planning/roadmap.md`（若合并）
  - [ ] `product/`（若改能力）
  - [ ] `product/README.md` 索引状态（若绑定设计稿：`部分落地` / `已验收`）
  - [ ] OpenAPI → `<host-openapi>/`（若改 API）
- [ ] Spec 状态/下一步/blocker 变化时，`reference/handoff.md` 对应行已更新
- [ ] `VERSION.md` status → done（合并后）

## 验证报告

见宿主 `AGENTS.md` 验证约定。
