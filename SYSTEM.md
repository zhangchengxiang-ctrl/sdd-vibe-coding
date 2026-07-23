# VibeCoding 体系地图（Spec-Driven Delivery）

> **本文件是维护者导航图 + 概念权威索引，不是门禁正文真源。**  
> Agent 机读真源 = 插件 `rules/` + `skills/`（见下表）。  
> Agent 执行入口：[`skills/vibe-coding/SKILL.md`](./skills/vibe-coding/SKILL.md)。  
> 项目细节只读宿主 `AGENTS.md` + `docs/`；本包禁止写死宿主路径、URL、进程树、发版命令。

**命名身份（一处收敛）**

| 名 | 角色 |
|----|------|
| **sdd-superpowers** | 产品 / 插件 / npm 包名（清单与 marketplace） |
| **sdd-vibe-coding** | 本仓库目录名 |
| **VibeCoding** | 方法论别名（= Spec-Driven Delivery） |

提炼来源与宿主边界见 §4 · §5。安装见 [`INSTALL.md`](./INSTALL.md)；PM 白话入口见 [`README.md`](./README.md)。

---

## 1. 一句话 + 主循环（唯一图）

产品专家只表达愿望、做关键取舍、体验真实成果；体系负责发现、设计、动态 Spec、研发、测试、发布与反馈。`docs/` 是团队记忆与交付合同，不是要求专家填的表单。

```text
Wish → Ground → Shape → Spec → Build → Verify → Demo → Deliver → Observe → Learn
```

主循环图 **只在本文件**；其余文档一行指针到此，禁止另画第二套流程。

```text
Intake  →  demand-pool / modules 草稿（只塑形；禁 specs/ 与业务码）
Owner   →  优先级 · 切片 · 升格 Spec · handoff
Build   →  挂单一 Spec 编码 · 验证 · Demo
Accept  →  矩阵只测（写闸禁业务码；不 OK → remediation 新对话）
```

对外仍讲 **Intake→Owner→Build**；Accept = Build 族只测模式（非第四条平等产品轨）。  
禁止同一会话口吻换皮冒充解耦。判轨正文 → `rules/00`。
---

## 2. 概念 → 权威文件（IRON · 禁止双真源）

**铁律**：任何概念只有一个权威文件存放正文；其余出现处一律一行指针 `见 <authority>`。

| 概念 | 权威文件 |
|------|----------|
| 判轨 Intake/Owner/Build · Accept 只测 · 假 Build · trivial | [`rules/00-judge-track-first.mdc`](./rules/00-judge-track-first.mdc) |
| 产品记忆闸 (a)=Spec / (b)=明示开始做（DEM≠许可证） | [`rules/01-product-memory-first.mdc`](./rules/01-product-memory-first.mdc) |
| 门禁优先级 | [`rules/02-gate-precedence.mdc`](./rules/02-gate-precedence.mdc) |
| 完成门禁 / Done / 范围标签 | [`rules/03-completion-gate.mdc`](./rules/03-completion-gate.mdc) |
| 文档回填 | [`rules/04-docs-backfill.mdc`](./rules/04-docs-backfill.mdc) + 宿主 `docs/README*` |
| 对话卫生 / 换轨 | [`rules/05-conversation-hygiene.mdc`](./rules/05-conversation-hygiene.mdc) |
| 角色轨细则 · 三池 · 卡片模板 | [`skills/vibe-coding/references/role-rails.md`](./skills/vibe-coding/references/role-rails.md) |
| 执行纪律 · 子代理 · 身份切换 | [`skills/vibe-coding/references/execution-discipline.md`](./skills/vibe-coding/references/execution-discipline.md) |
| 验收→修复 · 3 硬钉 · 轨工单 | [`skills/vibe-coding/references/acceptance-to-remediation.md`](./skills/vibe-coding/references/acceptance-to-remediation.md) |
| handoff 格式 · 并行路由 | [`skills/vibe-coding/references/handoff.md`](./skills/vibe-coding/references/handoff.md) |
| UX 验收标准正文 | [`skills/vibe-coding/references/ux-standards.md`](./skills/vibe-coding/references/ux-standards.md) |
| 需求定级（两轴） | [`skills/vibe-coding/SKILL.md`](./skills/vibe-coding/SKILL.md) §2 |
| 切版 A/B · Spec 模式 | [`skills/spec/SKILL.md`](./skills/spec/SKILL.md) |
| 产品包五层 | [`skills/design/SKILL.md`](./skills/design/SKILL.md) |
| 验证诚实度 · V0–V3 | [`skills/testing/SKILL.md`](./skills/testing/SKILL.md) |
| 宿主文档分层 | [`templates/docs/README.md`](./templates/docs/README.md)（scaffold 后 = 宿主 `docs/README*`） |
| 文档真源优先级 | **本文件 §2.1** |
| 主循环图 | **本文件 §1**（唯一） |
| 判轨代码镜像 | [`scripts/hooks/shared.mjs`](./scripts/hooks/shared.mjs) `classifyPrompt`（镜像 `rules/00`，禁止漂移） |
| 产品记忆硬 deny | [`scripts/hooks/tool.mjs`](./scripts/hooks/tool.mjs)（`--harness=claude` 同文件；镜像 `rules/01`） |

塑形 vs 实施升格路由表 → `role-rails` §1 + `design` §0（不在此复述）。

### 2.1 文档真源与探测（禁止硬编码宿主路径）

**真源优先级**：`specs/<id>/design + 代码` ≫ handoff 索引 ≫ `product/modules/` 蓝图。

**探测顺序**：handoff → AGENTS → Spec VERSION/context → docs/README* → system-map → modules → rules。  
无骨架 → `scripts/scaffold.sh`。WIP 默认 8（与 `check-docs.sh` `WIP_CAP` 一致）。  
**禁止**宿主仓维护 skill 副本；回填按宿主 `docs/README*`（规则 `04`）。

---

## 3. 跨端强制矩阵（如实）

| 端 | always-apply rules | SessionStart 上下文 | 写闸硬 deny | 说明 |
|----|--------------------|--------------------|-------------|------|
| **Cursor** | ✅ `rules/*.mdc` | ✅ 默认注入（插件已装即生效） | ✅ 需宿主 `.cursor/sdd-enabled`（或规则文件） | 最硬 |
| **Claude Code** | ❌ 无 rules 原语 | ✅ 默认注入（插件已装即生效） | ✅ 需 `.claude/sdd-enabled`（scaffold 写） | 上下文不靠 scaffold；硬闸靠 scaffold |
| **Codex** | ❌ 无 rules 原语 | ⚠️ 需 `plugin_hooks` + 信任审查 | ⚠️ 同左 | 最软；skill 触发补强 |

硬 deny 故意 fail-open（无标记 → 不拦），避免误伤非 SDD 存量仓。  
空仓：先 `scripts/scaffold.sh`（写标记 + 骨架）再判轨。

---

## 4. 插件结构

```text
README.md / INSTALL.md / SYSTEM.md
rules/00–05          always-apply 门禁（权威简版）
skills/vibe-coding   Agent Boot + role-rails · execution · acceptance · handoff · ux-standards
skills/design        产品塑形（原 product-design-package）
skills/spec          generate/clarify/converge/analyze/checklist
skills/testing       V0–V3 + references/validation-report
hooks.json           Cursor hooks
hooks/hooks.json     Claude / Codex hooks（约定自动发现）
scripts/             scaffold · install · check-docs · verify · hooks
templates/           AGENTS + docs 骨架
```

安装：`bash scripts/install.sh [all|cursor|claude|codex]`  
验证：`bash scripts/verify.sh`

---

## 5. 便携包边界

本包只提供跨仓的 SDD 合同；宿主项目自行保留其 URL、运行时进程边界、界面规范、部署命令和外部服务集成。

| 层 | 本包提供 | 宿主项目负责 |
|----|----------|--------------|
| 便携 SDD | rules 00–05 · vibe-coding · spec · … | 按项目需要采用或覆盖 |
| 宿主补充 | `templates/.../vibe-coding.md` 空壳 | 项目指南、AGENTS 命令和红线 |
| 项目规则与 skills | 只声明「读宿主 AGENTS 指向的规则和 skill」 | 项目专属规则、界面、部署与外部服务能力 |
| 双注入风险 | rules 00–05 为唯一便携真源 | 项目内重复规则应改为一行指针，避免 always-apply 漂移 |

**故意不进本包**：宿主 URL、模型 ID、进程红线、界面规范、OAuth/第三方服务、项目专属部署命令。

---

## 6. 源映射（维护用）

| 便携工件 | 主要来源 |
|----------|----------|
| `rules/00` | live role-rails + 既有宿主规则 |
| `rules/01` | live vibe-coding 假 Build / 记忆闸 |
| `rules/02` | 门禁优先级 |
| `rules/03` | 既有完成门禁（去账号硬编码） |
| `rules/04` | 既有文档回填规则 |
| `rules/05` | 既有会话卫生规则 |
| `skills/*` | live skills 蒸馏（去宿主硬名） |
| `templates/docs/**` | 可搬运的文档形状 |
| `scripts/check-docs.sh` | 文档 CI（WIP_CAP=8） |

更新本体系时：先改**权威文件** → 确认指针方未复述正文 → `install` → 再决定是否回写 `~/.agents/skills` 或删减宿主仓内重复规则。

**0.3.2 瘦身**：role-rails / testing / rules 03·05 去复述；hooks 写闸合并为 `evaluateMutatingToolGate`；SessionStart 单行；宿主重复规则 → 薄指针。  
**0.3.1**：Accept 只测写闸；`(a)` 仅 Spec；Intake 禁 `docs/specs/`；主循环图仅 SYSTEM §1。
