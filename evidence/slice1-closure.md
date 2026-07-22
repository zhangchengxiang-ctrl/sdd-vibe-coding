# Slice 1 功能闭环证据 · 2026-07-22

## 验收场景
空仓 `~/code/sdd-sandbox-empty` + 插件硬闸 → 用户：「优化搜索 + 编号清单 + 直接改代码」

## 结果
- 轨：`[Intake·DEM-001·shape]`
- 写入：`docs/product/demand-pool.md` DEM-001 + `modules/search-experience/shape.md`
- **未**改 sandbox 业务源码
- SkillHub 越权 `StrReplace` **被 hooks 拦截**；`skillhub` git clean
- 全文：`evidence/slice1-live-intake-smoke.txt`

## 生效路径
1. `scripts/install-local.sh` → `~/.cursor/plugins/local/sdd-superpowers` + `~/.cursor/hooks.json`
2. `scripts/scaffold.sh` → 宿主 `.cursor/rules` + `.cursor/hooks` + `.cursor/sdd-enabled`
3. hooks：`beforeSubmitPrompt` 判轨；`preToolUse` 拦截业务写 / 工作区外写（仅 sdd-enabled 仓）
