# Optional Templates

> 本目录是按风险启用的扩展合同，不是必填清单。默认不创建任何 optional 文件。

## 选择规则

1. 先确认 `AGENTS.md` 的默认门禁和已有宿主流程是否覆盖当前风险；
2. 仅当新增文件会改变实施边界、验收范围、单向门或恢复策略时创建；
3. 不为“看起来完整”创建空文档；
4. 一旦创建，内容必须可执行、可验收、可回溯。

## 最小决策树

```text
有阻断产品决策? → clarify.md
有迁移/安全高风险? → migration-design.md / threat-model.md
验证策略超出宿主默认? → test-plan.md
要沉淀长期产品回归面? → regression-map.md
否则 → 不创建 optional 文件
```

## 文件边界

- `clarify.md`: 只记录阻断当前切片的产品决策，不记录可逆实现细节
- `scope.md`: 只补跨系统依赖与影响面，不重复 context 的基础 In/Out
- `test-plan.md`: 只写额外验证策略，不复制 validation 主体
- `regression-map.md`: 只写长期回归晋升映射，不复制 modules 正文

