# CLI 派发授权块

> `codex-dispatch.sh` 对 **plan|build|goal** 一律把下列正文**前置**注入 prompt。  
> 改条文时同步改 `scripts/codex-dispatch.sh` 内 `AUTH_BLOCK`。

## 为何需要

宿主 `AGENTS.md` 常写「新产品能力须先在聊天贴计划并等人批」；Codex 还会调用 `doc-coauthoring`。  
在 `approval_policy=never` 的非交互 `codex exec` 里，这会导致 **exit 0 + 零落盘** 的假成功。

## 注入正文（语义合同）

1. 本回合无真人；`approval_policy=never` 已生效。  
2. 指挥侧/许愿路径**已授权**本 unit；禁止「待批准 / 可以开始」停点。  
3. 宿主 AGENTS 的「先计划再批准」对**本 CLI 派发**视为已满足。  
4. 禁止 `doc-coauthoring` / 等人确认 / 反问收尾；不确定标 `Unverified` 或 `blocked`+缺什么。  
5. 先工具写盘；终消息短状态+证据；成功=仓库变化。

Pack 侧 Constraints 须与此一致（见 `build_context_pack.py`）。
