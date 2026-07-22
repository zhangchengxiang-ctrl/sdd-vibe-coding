#!/usr/bin/env node
import path from 'node:path'
import fs from 'node:fs'
import { readStdin, parseHookInput, out } from './lib.mjs'

function sddEnabled(roots = []) {
  return roots.some((r) => {
    try {
      return (
        fs.existsSync(path.join(r, '.cursor', 'sdd-enabled')) ||
        fs.existsSync(path.join(r, '.claude', 'sdd-enabled')) ||
        fs.existsSync(path.join(r, '.cursor', 'rules', '01-product-memory-first.mdc')) ||
        fs.existsSync(path.join(r, '.claude', 'rules', '01-product-memory-first.md'))
      )
    } catch {
      return false
    }
  })
}

const raw = await readStdin()
const input = parseHookInput(raw)
const roots = input.workspace_roots || []

if (!sddEnabled(roots)) {
  out({})
  process.exit(0)
}

const ctx = [
  '【SDD Superpowers · 会话硬闸】',
  '1. 先判轨：歧义默认 Intake。优化/改进/编号清单/截图 ≠ 开始做。',
  '2. 产品记忆先行：无 modules/DEM/归属 Spec，且无明示「开始做/实现/按这个来」→ 只写 docs/product/ + 一屏 Shape；禁止业务代码。',
  '3. 空仓：先跑插件 scripts/scaffold.sh 生成 AGENTS.md + docs/。',
  '4. Intake 可写：docs/product/**、AGENTS.md；禁止改业务源码；禁止改工作区外仓库。',
  '5. 完成必带范围标签 [轨·范围·Delivery Target]。',
].join('\n')

out({
  additional_context: ctx,
  env: {
    SDD_SUPERPOWERS: '1',
    SDD_DEFAULT_RAIL: 'intake',
  },
})
