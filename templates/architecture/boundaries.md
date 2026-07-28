# Architecture Boundaries

> 只填本仓可核验事实。空项 = 沿用插件 design-standards 默认。

## 分层与目录

| 层（或宿主等价名） | 目录 / 包 | 职责一句话 |
|---|---|---|
| | | |
| | | |

## 依赖方向

```text
# 例：UI → Application → Domain ← Infrastructure
# 边界外（本仓不允许的跨层）：
```

-

## 公共契约真源

- API / schema / 事件合同：
- 生成命令：

## 写入边界

- 只读区域：
- 新建需批准的模式 / 目录：

## 模块 README 约定

- 路径模式：（例：`src/**/README.md`）
- 必含：职责、入口、依赖边界

## C4 摘要（可选）

```mermaid
flowchart LR
  User[User] --> Sys[System]
```

## 例外（覆盖插件默认）

| 插件条款 | 本仓做法 | 理由 |
|---|---|---|
| | | |
