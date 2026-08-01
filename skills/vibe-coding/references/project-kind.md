# 项目类型（`project.kind`）

> 入口第 0 闸。跨仓真源。会话硬闸见 `templates/.cursor/rules/sdd-vibe-entry.mdc`。

## 问题

装了插件规则的工作区**不都是**软件交付仓。若默认 `software`，会把插件源仓、笔记仓等强行拖进 Shape→Plan→Build。

## 枚举（仅三档）

| kind | 含义 | 本插件 |
|---|---|---|
| `software` | 应用/服务产品交付（宿主） | 编码 SDD 全轨 + 冷启动 Init/Onboard |
| `plugin` | 本插件或同类 skill/脚手架源仓 | 维护 skills/templates/scripts；笔记 plans/ |
| `other` | 其余（文档/数据/调研/运维等） | **放手**：只停用编码硬闸，不接管、不冷启动、不写操作卡 |

**禁止**在未探测/未确认时默认写成 `software`。  
不设 `docs`/`data`/`research`/`ops`/`mixed`/`unknown` 等平行枚举——一律归 `other`（任务若是软件交付，再升格为 `software`）。

## 探测顺序

1. `AGENTS.md`（或薄 `PROJECT.md`）已写 `project.kind` → 沿用；  
2. 启发式：本插件源仓信号 → `plugin`；有可运行应用 + 交付意图 → 倾向 `software`；否则 → `other`；  
3. 仍模糊 → 草案推荐三选一 + 理由；冷启动整轮拍板 ≤5 时 kind 至多 1 题。

## 与项目表单

仅 `software` 走 [`project-init.md`](../../design/references/project-init.md)。  
`project.kind` 为表单 Tier 0 第 0 项。`plugin` / `other` 不走编码项目表单。

## 路由后果

| kind | Agent 做什么 |
|---|---|
| `software` | vibe-coding 宿主轨（FIRST ACTION → 冷启动 / 判轨） |
| `plugin` | 读 ARCHITECTURE（或包说明）；改 skills/templates/scripts；笔记 plans/ |
| `other` | 停用编码硬闸后结束本插件流程；交给用户或其他 skill |
