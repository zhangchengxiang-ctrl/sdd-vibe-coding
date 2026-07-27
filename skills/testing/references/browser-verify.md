# 浏览器真实通道验证（V2）

> 跨仓通则。宿主 URL、前端根、reload / E2E 命令以 `AGENTS.md` 为准；本文件不写死单仓路径。

改用户可见前端后，在声称完成前必须做一次**真实浏览器通道**验证。输入是当前切片的用户
Job、Test（`tests.md`）、Effective Channel 和 Oracle。

## 探测（先读宿主）

| 项 | 如何确定 |
|----|----------|
| 前端根 | 读 `AGENTS.md` 代码入口；再按仓内约定探测（勿写死单仓目录名） |
| Dev / 目标 URL | **先读** `AGENTS.md` 环境表；再扫 handoff / 近期 `run.md` |
| 静态刷新 | `AGENTS.md` 或宿主 Makefile / 脚本中的 reload 目标 |
| E2E / 无头冒烟 | 宿主约定的 verify / e2e 命令；或仓内测试目录 |

## 场景分流

| 你在哪跑 | 浏览器手段 |
|----------|------------|
| **有 Browser MCP 的 IDE** | Browser MCP → 宿主声明的 Dev / 目标 URL（优先非错误主机的 loopback） |
| **无 Browser MCP**（远程 worker、无头 CI、网页 Agent） | Playwright / 宿主 `AGENTS.md` 约定的等价命令 |
| CI | 仓内 E2E / smoke 目标 |

**禁止**用下列手段冒充「已浏览器验证」：

- 仅 API 冒烟 / `curl /health` / 首页 HTTP 200
- 仅单元测试绿
- 对**错误主机**的 loopback（例如远程会话里打远端本机 `127.0.0.1`）冒充产品 Dev URL

## 回写（Demo / V2 Gate）

回写至少包括：

- 可体验入口、账号/角色与必要数据
- 用户实际操作步骤
- 结果是否满足 Oracle
- 截图/日志等证据路径
- 失败下一动作：按 [`evidence-contract.md`](../../vibe-coding/references/evidence-contract.md)
  Fail 分类路由（`shape` / `plan` / Repair / `blocked` / `diagnose` 等）——**没有**独立的
  `deliver` Rail

控件存在、API 成功或 fixture 绕过产品入口都不能冒充 V2 通过。产品专家看真实系统与证据，
不需要阅读测试命令。

## 身份切换

验收需要 Admin / 另一成员身份时：

1. 确认登录页是否有**账号密码**（或宿主约定的可复用测试登录）路径；
2. 有 → **自行**退出当前会话 → 用仓库 / 前次会话 / E2E 可复用凭据登录 → 继续走查；
3. 仅当路径是扫码 / SSO / 用户个人 OAuth / 必须真人本人时，才登记等人。

把「一键登录我走不了」当成整个登录硬限制 = **流程错误**。细则亦见
[`evidence-contract.md`](../../vibe-coding/references/evidence-contract.md) §6。

## 证据落盘

关键屏截图复制进宿主约定目录，路径写入 `run.md` 追踪矩阵 / 批次结果的 Evidence 列。

**禁止**只在对话里贴图、或留在工具临时目录就算验完；仓库内禁止把临时截图目录当正册。

## 完成定义

```text
改前端 → 直接相关静态/单元检查 → 一次浏览器真实通道验证 → 才可汇报完成
```

发布、CI、全局合同或仓内明确门禁之外，不默认叠加全量单测与全量 E2E。
稳定的新用户旅程可补 E2E；局部视觉、文案、布局调整不为凑流程新增 E2E。

若仓内启用验证 marker：只在真实验证完成后写入；**禁止**未验证只 touch marker。
