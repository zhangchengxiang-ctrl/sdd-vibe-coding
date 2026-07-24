# Commit / PR Checklist · <version-id>

> 仅在执行合同的 Delivery 明示 commit 或 PR 时使用；服从宿主 `AGENTS.md`。

## 提交前

- [ ] diff 只包含当前 Spec / PR 范围
- [ ] 没有 secret、临时日志或无关生成物
- [ ] Build Validation 已记录真实证据
- [ ] 分支、base SHA 和依赖 PR 与执行合同一致

## PR

- [ ] 标题和描述能说明独立价值切片
- [ ] 链接 Spec 和 validation/evidence
- [ ] 写明迁移、共享合同、回滚和集成重测
- [ ] CI 状态如实记录

## 合并后

- [ ] 依赖分支按计划同步
- [ ] 执行执行合同指定的 integration retest
- [ ] 更新 handoff 的 Spec / Branch / PR / Next
- [ ] 生产发布仍按独立授权与宿主流程执行
