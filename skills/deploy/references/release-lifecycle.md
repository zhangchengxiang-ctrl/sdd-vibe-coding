# 发布生命周期（P0–P6）

> 本文件是跨仓发布阶段与交付物的真源。宿主命令、URL、侧车清单以 `AGENTS.md`（及产品仓 deploy 适配器，若有）为准。  
> 关版证据条件仍以 [`evidence-contract.md`](../../vibe-coding/references/evidence-contract.md) Deliver Gate 为准。

## 一句话

**发布 = 有边界的变更交付：先用目标环境 diff 看清「代码 + 非代码」，再并列设计「怎么发」和「怎么证伪」，批准后才动生产，最后用验证方案关版——而不是用 deploy 命令的成功代替交付。**

## 六阶段

```text
P0 范围锁定      要发什么（sha / Spec / Delivery Target）
P1 Diff 与证据    目标环境现状 vs 待发变更（代码 + 非代码 drift）
P2 发布方案设计   怎么发（units、sidecar、顺序、回滚、延期项）
P3 验证方案设计   发完怎么证伪（冒烟层 + 失败标准）← 与 P2 同级，先于执行
P4 批准门禁       人确认（L1/L2）；L0 可对话一句批准
P5 执行           sidecar → deploy/reload → health（过程检查）
P6 生产验证+关版  跑 P3；打标签；回写 Spec `run.md`
```

### 硬规则

1. **缺 P2 或 P3 → 禁止 P5**（L1/L2）。  
2. **health / 进程 active / 首页 HTTP 200 只属于 P5 过程检查，不是关版依据。**  
3. **P6 未过 → 标签只能是 `prod-smoke 未过/Blocked`，禁止宣称 `production-delivered`。**  
4. **Dev / 预览结果最多进 P1「旁证」，不能替代 P6。**  
5. **脚本（路径信号、reload 计划、env 清单）只采集证据，不定级、不批准、不自动改生产配置。**

### 与旧叙述对齐

```text
现有粗流程: 证据 → 定级 → 贴方案(含冒烟) → deploy → 跑冒烟 → 标签
本文件:     P1证据 → 定级 → P2发布设计 + P3验证设计 → P4批准 → P5执行 → P6验证关版
```

## 定级（L0 / L1 / L2）

由 Agent/人在对话声明 `DECLARED_TIER` + 理由；**禁止**仅用路径 glob 冒充定级。

| 级 | 何时判 | Diff / 动作深度 | P2+P3 / P6 |
|----|--------|-----------------|------------|
| **L0 热修** | 单 deploy unit；无迁移 / 新 env 合同 / 主机依赖 / 特权 helper / ACL·权限模型 / 发布面语义风险 | 只 reload | 极简（触及面 + 最小冒烟）；一句批准 |
| **L1 常规** | 多单元，或有真实产品影响的侧车（Hub/集成/ACL/依赖等） | sidecar + 新 env 键 | **完整** 采纳表 + 冒烟层 |
| **L2 大版本** | 迁移、主机依赖、特权 helper、systemd/反向代理、env 合同、单向门、或大包上生产 | 全矩阵；**默认**对比目标生产现状 | 全矩阵 + 加长走查 |

**误判 L0 禁令：** P1 出现迁移、主机依赖、反向代理/进程模板、新 env 合同键等强信号时，**禁止**自判 L0，除非理由写清「为何该 signal 可忽略」。

Spec 仍为 `dev-effective` 却要上生产：定级旁必须写 **风险接受**；P3/P6 用 L2 加长清单。

### 按级裁剪

| 级 | P1 | P2+P3 | P4 | P5 | P6 |
|----|----|-------|----|----|-----|
| **L0** | 轻量 diff | 极简 | 一句批准 | 单 unit reload | 最小冒烟 |
| **L1** | 全证据 | 完整采纳表 + 冒烟层 | 要批准 | sidecar + deploy | 完整勾选项 |
| **L2** | + 目标环境对比（默认开启） | 全矩阵 + 加长走查 | 要批准 | 全 sidecar | 完整 + 加长 |

## P1 · Diff 与证据（判断，不是执行）

输入：`BASE=<目标环境当前 tip 或 prod-sha>`，`HEAD=<待发 tip>`。

输出（对话可贴表）。须分开列 **「仓库已改、生产未应用」** 与 **「本次 diff 新改」**，避免「模板在 git 里」被当成已上线。

| 类 | 内容 |
|----|------|
| 代码面 | deploy units（按宿主进程/包边界） |
| 合同面 | migrate / env 新键 / OpenAPI / 权限边界 |
| **运维面** | 反向代理 / systemd（或等价）/ host-deps / helpers / ACL / 外部 scopes |
| **Drift** | 仓内模板 vs **live** 配置；目标环境依赖检查；未应用的延期 MUST |
| 定级建议 | L0/L1/L2 + 理由（人/Agent 声明） |

## P2 · 发布方案设计（怎么发）

固定四块：

1. **执行序**：env → migrate → host-deps → sync 配置模板 → reload 顺序（按宿主裁剪）  
2. **Sidecar 采纳表**：每条 MUST/WARN → `本次执行 | 明确延期（理由+跟踪）| N/A`  
3. **回滚**：代码回退 sha；migrate / 配置是否可逆  
4. **风险接受**：若 Spec 仍是 `dev-effective` 却上生产，必须显式写

反向代理 / 进程模板类 MUST 必须写成：

`diff 模板↔live → 同步 → 语法检查 → reload →（见 P3 边车冒烟）`  

禁止只写 `reload nginx` / `systemctl reload …` 而不含 sync live。

## P3 · 验证方案设计（怎么证伪）——与 P2 同级

在**动手前**写完。按信号勾选；每条写清：**步骤、期望、证据形式、失败归类（回滚 / 热修 / 已知延期）**。

| 层 | 何时必有 | 示例 |
|----|----------|------|
| **K0 过程** | 每次 | 进程 active、health、migrationStatus=ready（或宿主等价） |
| **K6 关键路径** | L1/L2 | 本批 1～2 条**已登录/已认证**成功路径 |
| **K-ops** | 触及反向代理 / 主机依赖 / 特权 helper / 延期同类 MUST | 与本次配置相关的一项（上传/大 body/WS/依赖二进制路径等） |
| **K1–K5** | 按宿主 release 清单 | 预置 / 路径 / ACL / 发现面 / 用户投影等产品面 |

未勾选的项须写 `N/A` + 一句理由。

## P4 · 批准

- **L0**：对话「可以发」即可（方案可极简，仍须触及面最小冒烟）  
- **L1/L2**：P2+P3 贴出后，明确批准才进 P5  

生产动作另遵宿主 `AGENTS.md` 的部署授权；批准本阶段 ≠ 自动授权不可逆数据操作。

## P5 · 执行

只执行 P2 已采纳项。顺序建议：

1. 目标机取得约定 tip（禁止用源码/dist 直拷代替宿主规定路径）  
2. 环境门禁（`check-env` 或宿主等价）  
3. 采纳的 sidecar  
4. deploy / unit reload  
5. health **仅作过程检查**

## P6 · 生产验证 + 关版

1. 按 P3 在**目标环境**执行；Dev 结果不可填「prod-smoke 通过」  
2. **Agent 先探活**：有 Browser MCP / 宿主 smoke 命令则自行打开目标 URL 或跑脚本；挂了打 `未过/Blocked` 并给回滚建议，**禁止**请用户打开/硬刷当第一发现人  
3. 完成标签强制带冒烟态：  
   `[部署·L#·prod-smoke 通过]` / `[部署·L#·prod-smoke 未过/Blocked: …]`  
4. 回写 Spec `run.md` Deliver Gate 字段（含 `探活执行者` / 产品冒烟证据 / `需要用户做什么`）；延期 sidecar 挂 **Open MUST** 到下次 P1  
5. 仅 P6 通过且声明目标为生产时，才可写 `production-delivered`

通则：[`verification-loop.md`](../../vibe-coding/references/verification-loop.md)。

## 发布方案模板（贴对话 · 缺块即不合格）

```markdown
## 发布方案 · <日期> · BASE=<sha> → HEAD

### P0 范围
- Spec / Delivery Target:
- BASE / HEAD:

### 定级（Agent/人判定，非脚本）
- DECLARED_TIER: L0 | L1 | L2
- 理由: （证据哪些采纳/忽略；单向门）
- 风险接受（若 Target ≠ production-delivered）: 是/否 + 一句

### P1 证据摘要
- units:
- signals:
- drift（仓内已改 vs live 未应用）:
- Dev 旁证（可选，非关版）:

### P2 执行清单
- 执行序:
- Sidecar 采纳表: （本次执行 | 延期+跟踪 | N/A）
- 回滚:

### P3 验证清单（与 P2 同级 · 执行前写完）
- 目标 URL / 主机:
- [ ] K0 过程: …
- [ ] K6 关键路径: <步骤 / 期望 / 证据 / 失败归类>
- [ ] K-ops: …（N/A 理由: ）
- [ ] K1–K5（按宿主）: …
- 预计证据形式: 浏览器快照 / SQL / API（目标环境）

### P4 批准
- 批准人 / 时间: （执行前填写）

### P5 / P6（执行后填写）
- 实际执行:
- 产品冒烟: 通过 | 未过 | Blocked+原因
- 探活执行者: agent | blocked-needs-auth
- 产品冒烟证据: kind=… · …
- 需要用户做什么: 无需动作 | …
- 完成标签: [部署·L#·prod-smoke …]
- Open MUST（延期项）:
```

## 运维侧车（抽象 A–J）

宿主可映射到本仓真实命令；未触及则 N/A。

| 层 | 典型信号 | 动作方向 |
|----|----------|----------|
| A reload | 应用源码 / 静态资源 | 宿主 deploy / unit reload |
| B 依赖锁 | lockfile | 宿主包安装 |
| C host-deps | 主机依赖脚本/文档 | setup + check |
| D 柜/工具链 | 特权 bin / provider | 同步并校验路径 |
| E migrate | migrations | migrate；health ready |
| F env 新键 | `.env*.example` | 主机手工补键（禁止把本地 overlay 拷到生产） |
| G ACL / 授权 | provisioning / grants | 回刷或愈合评估 |
| H 发现面 / Hub | catalog / install 契约 | 双单元 reload 等宿主要求 |
| I 进程/代理模板 | systemd / nginx 等 | **sync live** → 检查 → reload |
| J 外部 scopes | 飞书/OAuth 等 | 产品适配 skill 开缺口，禁止用错误入口冒充开通 |

## 与 Verify / Deliver Gate

| 角色 | 职责 |
|------|------|
| 本生命周期 | 发布全过程：方案、批准、执行、关版标签 |
| Skill `testing` | 可在用户只要「验收生产」时执行 P6 核对；不改实现、不擅自开 P5 |
| `evidence-contract` | `production-delivered` 与 `/health≠交付` 的硬门 |

`make deploy` / 远程一键发布脚本结束 **≠** 发布完成；必须继续 P6。
