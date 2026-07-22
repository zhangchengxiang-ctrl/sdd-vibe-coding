#!/usr/bin/env node
import {
  readStdin,
  parseHookInput,
} from './lib.mjs'
import { resolveWorkspaceRoots, sddEnabled, claudeOut } from './harness-lib.mjs'

const raw = await readStdin()
const input = parseHookInput(raw)
const roots = resolveWorkspaceRoots(input)

if (!sddEnabled(roots)) {
  claudeOut({})
  process.exit(0)
}

const ctx = [
  '【SDD Superpowers · 会话硬闸】',
  '1. 先判轨：歧义默认 Intake。优化/改进/编号清单/截图 ≠ 开始做。',
  '2. 产品记忆先行：无 modules/DEM/归属 Spec，且无明示「开始做/实现/按这个来」→ 只写 docs/product/ + 一屏 Shape；禁止业务代码。',
  '3. 空仓：先跑插件 scripts/scaffold.sh 生成 AGENTS.md + docs/。',
  '4. Intake 可写：docs/product/**、AGENTS.md；禁止改业务源码；禁止改工作区外仓库。',
  '5. 完成必带范围标签 [轨·范围·Delivery Target]。',
  '6. 主入口 skill：vibe-coding；切版用 spec；设计包用 product-design-package。',
].join('\n')

claudeOut({
  hookSpecificOutput: {
    hookEventName: 'SessionStart',
    additionalContext: ctx,
  },
})
