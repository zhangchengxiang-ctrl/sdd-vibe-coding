# Commit Checklist · <version-id>

> 提交与 PR 规范。配合 `AGENTS.md` 与文档回填规则。

## 提交前

- [ ] diff 仅包含本版本 scope（无无关格式化）
- [ ] 无 `.env` / secret 进仓库
- [ ] commit message：Conventional Commits（`type(scope): description`）

## PR

- [ ] 标题含版本 ID 或功能摘要
- [ ] 描述链到 `docs/specs/<id>/`
- [ ] 附 validation 报告摘要（含 **Docs 回填**）
- [ ] CI 绿

## 合并后

- [ ] `VERSION.md` → `done`，填合并日期
- [ ] `docs/planning/roadmap.md` 更新状态
- [ ] 按 [docs/README.md](../../README.zh-CN.md) 回填矩阵
- [ ] 若绑定设计稿：`product/README.md` → `部分落地` / `已验收`
- [ ] `reference/handoff.md` 更新
- [ ] 生产：`make deploy` / `make deploy-ccc`（按改动单元）
