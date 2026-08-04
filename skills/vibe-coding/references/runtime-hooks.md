# Runtime Hooks（运行时硬闸）

> 把写码闸 / Deploy P4 从「提示词自觉」升到 **Cursor/Claude hooks**。  
> 真源脚本：`scripts/hooks/`。宿主投影：`templates/.cursor/hooks*`、`templates/.claude/hooks*`。

## 装到宿主

```bash
make scaffold HOST=/path/to/repo WITH_HOOKS=1
# 或
bash scripts/scaffold.sh /path --hooks
```

要求：本机已 `make install-cursor`（wrappers 解析 `~/.cursor/plugins/local/sdd-vibe-coding`），或设 `SDD_VIBE_ROOT` 指向本插件仓。

Claude：把 `settings.sdd-hooks.json` 的 `hooks` 段合并进 `.claude/settings.json`。

## 授权标记

| 标记 | 含义 | 命令 |
|------|------|------|
| `.sdd/authorize.build` | 允许改业务代码 | `make sdd-authorize HOST=. KIND=build` |
| `.sdd/authorize.deploy-p4` | 24h 内允许生产/deploy 类命令 | `make sdd-authorize HOST=. KIND=deploy-p4` |

方案确认 / `wish-journey --set planning|building` 会自动确保 build 标记。  
**关版 ≠ 上线：** deploy 标记必须本轮明示后另开。

建议 gitignore：`.sdd/authorize.*`

## 旅程状态机

```bash
make wish-journey HOST=. SPEC=my-spec STATUS=1
make wish-journey HOST=. SPEC=my-spec SET=design-ready
make wish-journey HOST=. SPEC=my-spec TRANSITION=planning
```

状态落在 `.sdd/journey/<spec>.env`。合法转移见 `scripts/wish-journey.sh`。  
`wish-orchestrate` 派片后会尽力写入 `awaiting-falsify`。

## 自检

```bash
make hooks-selftest
make public-gates
```

## 旁路

| 变量 | 行为 |
|------|------|
| `SDD_BUILD_AUTHORIZED=1` | 等同 build 标记 |
| `SDD_DEPLOY_AUTHORIZED=1` | 等同 deploy-p4 |
| `SDD_HOOKS_SOFT=1` | 写码闸改 ask（不 deny） |
| 插件缺失 | wrapper **fail-open**（allow + agentMessage） |
