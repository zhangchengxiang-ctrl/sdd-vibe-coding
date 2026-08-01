# AGENTS.md — 项目事实

> 由 Vibe Coding scaffold 显式初始化。只填写本仓可核验的事实、命令和约束。
> 跨仓 SDD 流程以已安装插件 **skills**（入口 `vibe-coding`）为准，不在本文件复制全文。
> 本文件是宿主**唯一**项目事实面（含就绪度、共享资源、本仓例外）。

## SDD

- SDD docs root: docs
- **入口：** 产品 / 编码 / 验收 / 发布意图 → 先加载插件 skill **`vibe-coding`**，再读本文件。
- 未明示「开始做 / 实现 / 按这个来 / 构建」、且无已确认 `<SDD docs root>/specs/<id>/` → 只写 `<SDD docs root>/product/`，**不改业务代码**。
- **Build ≠ Deploy：** 生产发布须 Deploy 轨（P2+P3 → 本轮 P4 → P5 → P6）；仅「批准 Build」不得上生产。
- 无 `AGENTS.md` / SDD 文档树时先跑插件 `scripts/scaffold.sh`（存量推荐 `PROFILE=minimal` 或默认 `detect`；宿主已占用 `docs/product` 时用 `--root=docs/sdd`）；scaffold **不算**编码许可。硬冲突见探测输出的 `BLOCK`。
- 技能里写的 `docs/product`、`docs/specs` 均相对本文件的 **SDD docs root**（默认 `docs`）。
- 未经当前代码、Schema/约束、配置或运行证据验证的关键技术判断，标为 `Unverified`；仅 `Verified` 可进 P0 Requirement、Lock、Blocker、DDL 条件与可实施宣称。
- Codex：整份 Spec 长程「不要中途停止」→ 使用持久 Goal；普通回合只承诺一个纵向切片。
- 用户自然语言意图即可触发 Plan/Build；质量条（事实映射、纵向切片、TDD 用例）由插件默认执行。
- Cursor/Claude 上可说「派 Codex」走可选指挥施工（Skill `dispatch-codex`）；经
  `codex-dispatch.sh` / `make codex-dispatch` 派发；默认 `gpt-5.6-sol` × medium（加码 high）；
  `approval-policy=never`；Build 默认 `danger-full-access`。  
  **硬门：** 派发不经 `user-codex` / CallMcpTool。纯 Codex 会话自行 Plan/Build。
- 本仓命令、环境、单向门以下文为准。

## 项目

- 产品/服务：
- 主要技术栈：
- 代码入口：
- 默认分支：

## 项目就绪度

| 能力 | 状态 | 负责人 / 入口 |
|---|---|---|
| 本地启动与定向验证 | ready / missing | |
| 用户可见页面验收 | ready / missing / n/a | |
| 日志与监控只读入口 | ready / missing / n/a | |
| Preview / Staging | ready / missing / n/a | |
| 部署与回滚 | ready / missing / n/a | |

## 环境与入口

| 环境 | URL / 访问方式 | 版本识别 | 日志 / 监控 |
|---|---|---|---|
| Local | | | |
| Preview / Staging | | | |
| Production | | | |

生产 SSH、数据库、部署和回滚入口只写安全的定位方法，不写密钥。

## 常用命令

```bash
# 安装：
# 启动：
# 定向测试：
# 全量测试：
# lint / typecheck：
# build：
```

## 架构与写入边界

> 默认可执行原则：插件 `design-standards`（system-architecture / ux / visual）。
> 下列空项 = 沿用插件默认；填写即覆盖。可选站立文档：`docs/architecture/`。

- 进程 / 部署单元：
- 分层或目录约定：
- 依赖方向（一句话或箭头）：
- 公共 API / schema 真源：
- 生成物及生成命令：
- 模块 README 约定路径：
- 写入边界 / 只读区域：
- 体验 / 视觉 / 无障碍例外（相对插件 design-standards）：
- 设计系统 / 品牌真源（若有）：
- Default UI surface（product|consumer|n/a）：
- 可选产品寄存器：`docs/product/PRODUCT.md`（用户/Job/反参考；模板见插件 scaffold）
- 可选设计上下文：`docs/product/DESIGN.md`（锚点、品牌色、字体、反参考；模板见插件 scaffold）
- **DS 绑定（可选）：** 若 `组件库=antd`，施工前读 Ant Design「for agents」文档与项目 token；用官方组件 API，禁止手搓第二套近似皮肤。其他 DS（shadcn 等）同理：一项目一系统。

## 验证

| 变更 | 最低验证 |
|---|---|
| 后端逻辑 | 相关静态检查 + 单元/集成 |
| 用户可见前端 | 相关检查 + 真实浏览器 Scenario |
| 全栈 | 相关前后端检查 + 当前用户 Job |
| 数据库 / 单向门 | 迁移、兼容、health、回滚或本仓等价 |
| 发布 | P0–P6：证据 → 发布+验证方案 → 批准 → deploy → 目标环境产品冒烟关版（health 仅过程）；监控、回滚点 |

- 浏览器工具 / 账号：
- CI / 发布门：
- 发布证据 / 侧车命令（若有产品适配器）：

## 外部共享资源

| 资源 | 冲突规则 | 领取 / 释放方式 |
|---|---|---|
| 开发服务器 / 端口 | | |
| 数据库 / 测试数据 | | |
| 测试账号 | | |
| 浏览器 / 设备 | | |

## 单向门

只列本仓真实存在、执行前需要批准的事项；空槽删掉不适用的示例行。

- 事项 / 触发条件：
- 批准人或政策：
- 风险与回滚入口：

## Git 与交付事实

- 分支命名规则：
- Worktree 初始化 / setup 命令：
- 必跑 PR 检查：
- 分支保护与合并策略：
- commit / push / PR 是否需要单独授权：
- 部署与回滚授权：
- 共享数据库、端口、账号或浏览器限制：

## 本仓例外

只记录对插件通用默认值的项目级覆盖，并解释原因。无则写「无」。
