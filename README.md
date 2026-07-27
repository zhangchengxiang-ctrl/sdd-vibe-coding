# Vibe Coding

面向略懂技术产品经理的 **Spec-Driven Delivery** 插件（Cursor · Claude Code · Codex）。

用户表达诉求、判断关键取舍、授权实施并验收真实成果。跨仓工作流在 **skills**；本仓命令与红线在宿主 **AGENTS.md** / `docs/`。不依赖 rules / hooks。

> 用户前台保持简单；`docs/`、Spec、handoff 是 Agent 的内部交付记忆。

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
git clone <repo-url> sdd-vibe-coding
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
| `make scaffold HOST=/path/to/repo` | 宿主生成 `AGENTS.md` + `docs/`（默认 `HOST=.`） | 空仓 / 新宿主初始化 |
| `make verify` | 一键：布局 + templates docs + routing fixtures + scaffold | 改完脚本/布局/夹具自检 |
| `make check-docs DOC_ROOT=路径` | 只校验文档（默认 `./templates`） | 改文档模板或宿主 docs |
| `make eval-live` | Codex live 评测 | 有 Codex 环境时 |

安装在 cache stage **生成**各端清单（**不写入本仓库**），再注册。改仓库后 **不会自动热载**：再跑 `make install`（或开发期 `make install-dev`），然后：

| 端 | 装完后 |
|----|--------|
| Cursor | **Reload Window** → Plugins 见 **sdd-vibe-coding**；`~/.cursor/skills/` 已链 skill（可用 `/vibe-coding`） |
| Claude Code | `/reload-plugins` |
| Codex | 重启或**新开任务** → Plugins |

> Cursor 的 `/skill` 只扫描 `~/.cursor/skills/` 等目录，不扫描 `plugins/local`。`install` / `install-dev` 会把本插件 skills **同时**链到 `~/.cursor/skills/<name>`。若 `/vibe-coding` 仍提示 Create skill，先 Reload Window。

等价裸脚本：`bash scripts/install.sh […]`、`bash scripts/scaffold.sh <host>`。

## 空仓骨架

```bash
make scaffold HOST=/path/to/host-repo
```

只生成 `AGENTS.md`、可选 `CLAUDE.md`（`@AGENTS.md`）、`docs/`。不写 `.cursor/` / `.claude/`，不拷 check-docs。scaffold **不算**编码许可。

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
| `design` | Shape（含探索对话、代码库 grounding、产品包） |
| `spec` | Plan |
| `testing` | Verify / 证据（含浏览器真实通道、UX 走查变体） |
| `debug` | Diagnose / Incident |

只有 `vibe-coding` 默认可隐式触发；其余由主入口路由或显式调用。能力进 references，不另开平行 Skill。

## 维护者

见 [`evals/README.md`](./evals/README.md)。日常优先 `make verify`。
架构与真源分层见 [`ARCHITECTURE.md`](./ARCHITECTURE.md)。

## License

MIT
