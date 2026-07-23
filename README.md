# SDD Superpowers（VibeCoding）

让**不太懂技术的产品经理**也能用自然语言做 Spec-Driven Delivery：你说愿望，体系帮你塑形、排期、落地、验收——**没说「开始做」之前，不会乱动代码**。

| 名 | 含义 |
|----|------|
| **sdd-superpowers** | 插件 / 产品名（装到 Cursor · Claude Code · Codex） |
| **sdd-vibe-coding** | 本仓库目录 |
| **VibeCoding** | 这套方法论的别名 |

体系地图（维护者）→ [`SYSTEM.md`](./SYSTEM.md)  
安装细节 → [`INSTALL.md`](./INSTALL.md)  
Agent 入口 → [`skills/vibe-coding/SKILL.md`](./skills/vibe-coding/SKILL.md)

---

## 给产品经理：你说什么 → 会发生什么

| 你这样说 | 体系做什么 | 不会做什么 |
|----------|------------|------------|
| 「我希望…」「优化搜索体验」「改进顶栏」+ 编号清单/截图 | **Intake**：记进需求池，必要时写产品设计草稿 | 不改业务代码、不开实施 Spec、不承诺排期 |
| 「排期」「这周优先做哪个」「缓做 / 不做」 | **Owner**：改优先级、定首切片、必要时升格 Spec | 不写业务实现 |
| 「开始做」「按这个来」「实现」「构建」且切片已确认 | **Build**：按 Spec 编码、验证、给你看成果 | 不静默扩大需求 |
| 「跑验收」「走查」「总评」 | **Accept**（只测）：按场景矩阵逐条测；不 OK 开修复版工单 | 验收会话里不热修代码 |

**一句话铁律**：清单再清楚、截图再多，也不等于「开始做」。只有你明确说开始做（或已挂好 Spec），才会动业务代码。

### 示例对话

```text
你：优化一下扩展安装流程
    1. 安装成功要有反馈
    2. 失败要说人话
    3. 顶栏入口太深

Agent（Intake）：
  → 写 DEM-xxx 进需求池
  → 若成块，开/改产品设计包 modules/
  → 给你一屏 Intake Card（问题·非目标·未决）
  → 停。不改代码。

你：开始做，就按刚才那张卡的首切片

Agent（Owner→Build）：
  → 升格 Spec → 新对话编码 → Demo Card 给你看入口与证据
```

### 怎么唤起各轨（自然语言 · 无斜杠命令）

| 你说 | 走哪 |
|------|------|
| 「走 Intake / 记进需求池」 | Intake → `vibe-coding` + `role-rails` |
| 「排期 / 优先 / 升格」 | Owner → `role-rails` |
| 「开始做 / 按这个来」 | Build → `vibe-coding` + Spec |
| 「跑验收 / 走查」 | Accept → `testing` + `acceptance-to-remediation` |
| 「切版 / 消歧 / 收敛」 | skill `spec` |
| 「空仓 scaffold」 | `scripts/scaffold.sh` |

细则 → [`skills/vibe-coding/references/role-rails.md`](./skills/vibe-coding/references/role-rails.md)。

---

## 快速安装

```bash
bash ~/code/sdd-vibe-coding/scripts/install.sh
# 或：cursor / claude / codex
```

| Harness | 安装后 |
|---------|--------|
| Cursor | Reload Window → Plugins 见 **sdd-superpowers** |
| Claude Code | `/reload-plugins` → `/plugin` 确认 |
| Codex | Plugins → **SDD Superpowers (local)** → Install |

空宿主仓：

```bash
bash ~/code/sdd-vibe-coding/scripts/scaffold.sh /path/to/empty-repo
```

完整步骤、hooks 标记、验证命令 → [`INSTALL.md`](./INSTALL.md)。

---

## 当前版本 0.3.2

| 项 | 状态 |
|----|------|
| Cursor / Claude / Codex 三端插件 | ✅ |
| 判轨 · 产品记忆 · Intake→Owner→Build · Accept 只测 | ✅ |
| 编码许可证 = Spec 或明示开始做（DEM≠放行） | ✅ |
| 信息架构：rules+skills 唯一真源 · SYSTEM 地图 | ✅ |
| 自然语言唤轨（Intake/Owner/Build/Accept） | ✅ |
| Marketplace 公开发布 · 英文化 | ⏳ |

---

## License

MIT
