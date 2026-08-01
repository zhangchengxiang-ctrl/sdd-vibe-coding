---
name: deploy
description: >-
  跨仓发布 / 上线专项 Skill。触发：deploy / 发布 / 上线 / 发版 / 生产部署 /
  reload 上线 / 大版本发布。走 P0–P6（证据 → 并列设计怎么发与怎么证伪 → 批准 →
  执行 → 生产验证关版）；定级 L0/L1/L2 由人/Agent 声明（脚本不定级）；
  禁止仅用 health 或 Dev E2E 报部署成功。命令与环境只从宿主 AGENTS.md 读取。
---

# Deploy：发布生命周期

仅在 vibe-coding 已路由到 **Deploy**，或用户显式调用本 Skill 时使用。  
**不**替代 Shape/Plan/Build；**不**写业务功能代码（热修改码须另有 Build/Repair 授权）。

**交叉硬门（Build 窜入）：** 若当前会话只批准了 Build /「开始做」、且本轮未明示「部署 / 上线 / 发布」，**禁止 P5**。缺 P2/P3（L1/L2）或未获本轮 P4 → 停并摘要，不执行生产命令。

先读：

1. 宿主 `AGENTS.md`（部署命令、环境、URL、单向门、部署授权）
2. [`evidence-contract.md`](../vibe-coding/references/evidence-contract.md) Deliver Gate
3. 本目录 [`references/release-lifecycle.md`](./references/release-lifecycle.md)（P0–P6 真源）
4. 当前 Spec `VERSION.md` / `run.md`（Delivery Target、回写槽）

产品仓若另有 deploy 适配器（路径信号脚本、侧车清单），**叠加**使用；本 Skill 提供跨仓阶段门禁，不写死单仓路径。

## 本 Skill 铁律

1. **缺 P2（发布方案）或 P3（验证方案）→ 禁止 P5**（L1/L2）。  
2. **health / 进程 active / 首页 200 只属 P5 过程检查**，不能单独关版。  
3. **P6 未过 → 禁止 `production-delivered`**；标签须带 `prod-smoke 未过/Blocked`。  
4. **Dev / 预览最多作 P1 旁证**，不能替代 P6。  
5. **脚本不定级、不批准、不自动改生产 live 配置**；路径信号只提示。  
6. **禁止**把本地 `.env` overlay 拷到另一主机；禁止用源码/`dist` 直拷代替宿主规定发布路径（除非 `AGENTS.md` 明文允许）。  
7. P1 出现迁移 / host-deps / 反向代理·进程模板 / 新 env 合同等强信号时，**禁止**无理由自判 L0。

## 流程（硬顺序）

```text
P0 范围锁定（sha / Spec / Delivery Target）
 → P1 Diff 与证据（代码 + 非代码 drift）
 → 对话声明 DECLARED_TIER=L0|L1|L2 + 理由
 → P2 发布方案设计 + P3 验证方案设计（同级，先于执行）
 → P4 批准（L1/L2 须明确；L0 可一句）
 → P5 执行 sidecar → deploy/reload → health
 → P6 按 P3 在目标环境冒烟 → 标签 → 回写 run.md
```

L0：P2+P3 可极简（触及面 + 最小冒烟），仍禁止仅用 health 报成功。

## 谁做什么

| 谁 | 做什么 |
|----|--------|
| 宿主脚本 / 适配器（若有） | 列 units、path signals、候选 sidecar、可选生产对比；**提醒**冒烟层 |
| Agent / 人 | 定级；写 P2+P3；采纳或延期 sidecar；批准后执行；跑 P6；关版标签 |
| Skill `testing` | 用户只要「验收生产」时可只跑 P6 核对；不擅自开 P5 |

## 关版

完成标签示例：

- `[部署·L1·prod-smoke 通过]`
- `[部署·L2·prod-smoke 未过/Blocked: 反向代理未同步 live]`

延期 MUST 必须 Open 到下次 P1。Deliver Gate 回写字段见 `evidence-contract.md`。

对人前台：说清要发什么、风险级、批准点、冒烟是否通过；不堆内部阶段号，除非用户追问。
