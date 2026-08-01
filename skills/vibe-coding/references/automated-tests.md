# Build：自动化测试编写（跨仓通则）

> 与 Verify Skill `testing` 分工不同：本文管 **Build 期间写/跑自动化测试**；  
> 产品旅程验收、交付卡、UX 走查仍走 Skill `testing` + [browser-verify](../../testing/references/browser-verify.md)。

命令、夹具、目录只读宿主 `AGENTS.md`；不写死单仓路径。

## 原则

1. **绿套件 ≠ 可交付**：后端单测 / 组件测通过，不代替浏览器真实通道或 Spec Oracle。
2. **按层选测**：改哪一层就在哪一层加断言；跨层用契约或少量集成，避免全栈 E2E 堆砌。
3. **先失败场景**：权限拒绝、空态、非法输入与成功路径同等重要。
4. **回归挂在根因上**：Bug 修复后补覆盖该边界的用例，再重跑相关套件。
5. **数据面最低条**：触及分页/排序/筛选时，至少 1 个 API/契约测断言「不同 offset/参数 → 不同 rows」；纯前端 mock 列表测不能单独关闭该条。证伪通则见 testing [`falsify-checklist`](../../testing/references/falsify-checklist.md)。

## 默认分层（宿主可改名）

| 层 | 目标 | 常见做法 |
|----|------|----------|
| API / Router | 状态码、校验、响应形状 | HTTP test client；业务层可 mock |
| Domain / Service | 规则、状态机、领域错误 | 纯单测；仓储与外部依赖 mock |
| Persistence | SQL / 映射 / 级联 | 测试库或事务回滚集成测 |
| UI 组件 / Hook | 渲染、交互、缓存失效 | 组件测；网络 mock |
| E2E | 关键用户旅程 | Playwright 等；只覆盖稳定 P0 Job |

## 与交付的关系

| 改动面 | Build 最低自动化 | 仍须 |
|--------|------------------|------|
| 仅后端逻辑 | 相关单测 / API 测 | Spec 中非 UI Oracle（若有） |
| 仅前端 | 相关组件测（若仓内有） | [browser-verify](../../testing/references/browser-verify.md) V2 |
| 全栈入口 | 后端相关测 + 契约生成（若宿主要求） | V2 + 路由/入口按 `AGENTS.md` 核对 |

报告用语写清实际跑过的命令与覆盖面；禁止在只跑过后端套件时宣称「全量回归 / 可以发版」。
