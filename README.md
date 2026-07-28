# Vibe Coding

面向略懂技术产品经理的 **Spec-Driven Delivery** 插件（Cursor · Claude Code · Codex）。

用户表达诉求、判断关键取舍、授权实施并验收真实成果。跨仓工作流在 **skills**；本仓命令与红线在宿主 **AGENTS.md** / `docs/`。不依赖 rules / hooks。

> 用户前台保持简单；`docs/`、Spec、handoff 是 Agent 的内部交付记忆。

## 你需要什么

- 本机已安装至少一端：Cursor、Claude Code 或 Codex CLI
- Git + Make + bash
- 在**宿主业务仓库**里使用（本插件仓本身不是业务应用）

## 用户会看到什么

| 你这样说 | 体系做什么 | 不会做什么 |
|----------|------------|------------|
| 「我希望…」「优化这个体验」 | **Shape**：澄清并沉淀产品决策 | 不改业务代码 |
| 「按这个方向拆解」「准备实施」 | **Plan**：整份 Spec 执行合同与测试矩阵 | 不在规划对话编码 |
| 「开始做」「实施并验收这个 Spec」 | **Build**：连续实现与直接证据 | 不静默扩大 Scope |
| 「派 Codex 做」「用 Codex 施工」 | **指挥施工**（Cursor/Claude）：派单 + 验收 | 不把整包一次塞给 Codex |
| 「完整验收」 | **Verify**：按矩阵验证并分类问题 | 不边验边修 |
| 「修复这些验收问题」 | **Repair**：同根因集中修 | 不顺手扩需求 |
| 「排查线上问题」 | **Diagnose** | 不自动修复/部署 |
| 「立即恢复生产」 | **Incident** | 不做大规模重构 |

## 主流程

```text
Shape → Plan → Build(Spec) → Verify
                      ↑         │
                      └ Repair ─┘

Production issue → Diagnose → Incident / Repair / Plan / Blocked
```

写代码前硬闸见 `skills/vibe-coding/references/workflow-contract.md`（需已确认 Spec，或明示「开始做」且切片已确认）。

## 安装与常用命令（Make）

```bash
git clone https://github.com/<org>/sdd-vibe-coding.git
cd sdd-vibe-coding
make                 # 打印全部目标说明
make install         # 推荐：有 CLI 的端都装；缺则 SKIP
```

| 命令 | 做什么 | 何时用 |
|------|--------|--------|
| `make` / `make help` | 打印目标说明 | 忘了命令时 |
| `make install` | 装 Cursor + Claude + Codex（能装的才装） | 首次安装、改完 skill **正式**同步 |
| `make install-dev` | 同上，但 `skills/`/`templates/` **软链**本仓库 | 本地改 skill 少跑重装 |
| `make install-cursor` | 只装 Cursor | 只动一端 |
| `make install-claude` | 只装 Claude Code | 只动一端 |
| `make install-codex` | 只装 Codex | 只动一端 |
| `make scaffold HOST=/path/to/repo` | 宿主生成 `AGENTS.md` + `docs/`（默认 `HOST=.`，`PROFILE=detect`） | 空仓 / **存量**宿主初始化 |
| `make check-spec HOST=/path/to/repo SPEC=id` | Spec 静态门（事实映射 / tests / 架构节 / run 诚实性） | Plan 齐套后、派 Build 前 |
| `make codex-dispatch HOST=/path UNIT=plan\|build\|goal PROMPT_FILE=…` | 派 Codex（never + 墙钟超时；Build/Goal 需 `SPEC=`） | 指挥侧外包有界单元 |

安装在 cache stage **生成**各端清单（**不写入本仓库**），再注册。改仓库后 **不会自动热载**：再跑 `make install`（或开发期 `make install-dev`），然后：

| 端 | 装完后 |
|----|--------|
| Cursor | **Reload Window** → Plugins 见 **sdd-vibe-coding**；`~/.cursor/skills/` 已链 skill（可用 `/vibe-coding`） |
| Claude Code | `/reload-plugins` |
| Codex | 重启或**新开任务** → Plugins |

> Cursor 的 `/skill` 只扫描 `~/.cursor/skills/` 等目录，不扫描 `plugins/local`。`install` / `install-dev` 会把本插件 skills **同时**链到 `~/.cursor/skills/<name>`。若 `/vibe-coding` 仍提示 Create skill，先 Reload Window。

等价裸脚本：`bash scripts/install.sh […]`、`bash scripts/scaffold.sh <host>`。

## 宿主骨架（空仓 / 存量）

```bash
make scaffold HOST=/path/to/host-repo                 # PROFILE=detect（默认），SDD_ROOT=docs
make scaffold HOST=/path PROFILE=minimal              # 存量推荐：少铺空模板
make scaffold HOST=/path PROFILE=full                 # 全量 templates/docs
make scaffold HOST=/path SDD_ROOT=docs/sdd            # 宿主已占用 docs/product 时隔离
make scaffold HOST=/path DRY_RUN=1                    # 只探测，不写盘
```

| `PROFILE` | 行为 |
|-----------|------|
| `detect`（默认） | 空 SDD root → `full`；已有文件 → `minimal`；保留路径语义冲突 → **拒绝**（exit 2） |
| `minimal` | `AGENTS.md` + product 槽位 + `specs/_template` + `reference/`（不含空 foundation 等） |
| `full` | 整棵 `templates/docs` 写入 `SDD_ROOT` |

| `SDD_ROOT` | 行为 |
|------------|------|
| `docs`（默认） | 与技能文档中的 `docs/product` 等路径一致 |
| `docs/sdd` 等 | 写入子树，并在 `AGENTS.md` 盖章 `SDD docs root`；Agent 须按该根解析路径 |

探测会打印 `OK` / `SKIP` / `BLOCK`；**永不覆盖**已有文件。硬冲突：挪到 `docs/_host/`、改用 `SDD_ROOT=docs/sdd`，或 `ALLOW_PARTIAL=1`。

不写 `.cursor/` / `.claude/`，不拷 check-docs。scaffold **不算**编码许可。

## 权威分层

| 信息 | 真源 |
|------|------|
| 跨仓流程、判轨、完成语义 | 插件 `skills/` |
| 本仓命令、环境、红线 | 宿主 `AGENTS.md` |
| 产品决策 / Spec / handoff | 宿主 `docs/` |

## Skills

| Skill | 职责 |
|-------|------|
| `vibe-coding` | 宽入口；路由 Shape/Plan/Build/Verify/Diagnose/Incident |
| `design` | Shape（含探索对话、代码库 grounding、产品包；对照 design-standards ux/visual） |
| `spec` | Plan（含架构与设计边界轻门） |
| `testing` | Verify / 证据（含浏览器真实通道、UX 走查变体；ux 真源在 design-standards） |
| `debug` | Diagnose / Incident |
| `dispatch-codex` | 可选：Cursor/Claude 指挥 → Codex 施工（需用户明示） |

只有 `vibe-coding` 默认可隐式触发；其余由主入口路由或显式调用。能力进 references，不另开平行 Skill。

## 仓库里有什么 / 没有什么

**公开交付：** `skills/` · `templates/` · `scripts/` · `ARCHITECTURE.md`

**本机私有（已 `.gitignore`，仅本机）：** `evals/` · `plans/` · `minutes/` · `.env*` · 评测产物

## 安全

- API Key、`.env`、会议纪要、宿主业务仓 secrets 只留本机
- 公开仓不含评测夹具与内部计划；克隆后若本地没有 `evals/`，`make verify` 会提示跳过

## 架构

见 [`ARCHITECTURE.md`](./ARCHITECTURE.md)。

## License

MIT
