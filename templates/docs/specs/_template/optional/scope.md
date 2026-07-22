# Scope · <version-id>

## In Scope

- 

## Out of Scope

- 

## 依赖

| 类型 | 项 | 状态 |
|------|-----|------|
| 上游版本/PR | | |
| 外部系统 | | |
| 数据迁移 | | |

## 影响面预估

| 层 | 影响 |
|----|------|
| API | `<host-api-routes>/` |
| DB | `<host-db>/migrations.ts` |
| 前端 | `<host-ui>/src/` |
| Worker | `<host-worker>/`（若 run 注入相关） |
| 部署 | `宿主部署/reload 命令` 目标单元 |
