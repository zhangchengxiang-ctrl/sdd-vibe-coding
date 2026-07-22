# Design · <version-id>

> 本版本**实现级**设计。蓝图见对应 宿主 docs 设计稿。

## 方案概述



## 模块 / API

| 组件 | 路径 | 变更 |
|------|------|------|
| Web routes | `<host-api-routes>/routes.ts` | |
| OpenAPI | `<host-openapi>/document.ts` | |
| DB | `<host-db>/` | |
| 前端 | `<host-ui>/src/` | |
| Worker | `<host-worker>/` | |

## 数据模型

（表/字段/migration 摘要）

## 前端

（路由、页面、状态）

## 进程边界

- [ ] 若改 extensions：web 与 worker **分别**更新，不抽共享包
- [ ] Web 故障不得影响 worker run 语义

## 风险与回滚



## 引用专题设计

| 文档 | 链接 |
|------|------|
| | [`../../modules/<slug>/`](../../modules/<slug>/) |
