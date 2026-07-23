#!/usr/bin/env node
/**
 * Unit: Cursor + Claude harness Intake / Accept / Owner write gates
 */
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { classifyPrompt } from './hooks/shared.mjs'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const ws = '/tmp/sdd-verify-ws'
fs.rmSync(ws, { recursive: true, force: true })
fs.mkdirSync(path.join(ws, '.cursor', 'rules'), { recursive: true })
fs.writeFileSync(path.join(ws, '.cursor', 'sdd-enabled'), '1')
fs.writeFileSync(path.join(ws, '.cursor', 'rules', '01-product-memory-first.mdc'), 'x')
fs.mkdirSync(path.join(ws, 'docs', 'product'), { recursive: true })
fs.mkdirSync(path.join(ws, 'docs', 'specs', 'v2026.07-demo'), { recursive: true })

function run(script, input, extraArgs = []) {
  const r = spawnSync('node', [path.join(root, 'scripts/hooks', script), ...extraArgs], {
    input: JSON.stringify(input),
    encoding: 'utf8',
  })
  if (r.status) {
    console.error(script, r.stderr || r.stdout)
    process.exit(1)
  }
  return JSON.parse(r.stdout || '{}')
}

function assert(cond, code, msg) {
  if (!cond) {
    console.error('FAIL', code, msg)
    process.exit(code)
  }
}

// --- classifyPrompt ---
assert(classifyPrompt('优化X\n1、a').rail === 'intake', 10, 'optimize→intake')
assert(classifyPrompt('跑验收矩阵').rail === 'accept', 11, 'matrix→accept')
assert(classifyPrompt('帮我走查一下').rail === 'accept', 12, 'walkthrough→accept')
assert(classifyPrompt('开始做').rail === 'build', 13, 'start→build')
assert(classifyPrompt('实现上应该拆成两层').rail === 'intake', 14, '实现上→not build')
assert(classifyPrompt('排期这周优先').rail === 'owner', 15, 'owner')

// --- Intake: deny business, allow demand-pool, deny specs ---
run('prompt.mjs', {
  prompt: '优化X\n1、a\n2、b',
  conversation_id: 'v',
  workspace_roots: [ws],
})
const d = run('tool.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/src/x.ts', contents: '1' },
  conversation_id: 'v',
  workspace_roots: [ws],
})
assert(d.permission === 'deny', 2, 'intake deny business')
const a = run('tool.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/docs/product/demand-pool.md', contents: '1' },
  conversation_id: 'v',
  workspace_roots: [ws],
})
assert(a.permission === 'allow', 3, 'intake allow demand-pool')
const specDeny = run('tool.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/docs/specs/v2026.07-demo/VERSION.md', contents: '1' },
  conversation_id: 'v',
  workspace_roots: [ws],
})
assert(specDeny.permission === 'deny', 6, 'intake deny specs')

// --- Accept: deny business, allow specs evidence ---
run('prompt.mjs', {
  prompt: '跑验收矩阵',
  conversation_id: 'acc',
  workspace_roots: [ws],
})
const accBiz = run('tool.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/src/x.ts', contents: '1' },
  conversation_id: 'acc',
  workspace_roots: [ws],
})
assert(accBiz.permission === 'deny', 7, 'accept deny business')
const accEv = run('tool.mjs', {
  tool_name: 'Write',
  tool_input: {
    path: ws + '/docs/specs/v2026.07-demo/ux-test-results.md',
    contents: '1',
  },
  conversation_id: 'acc',
  workspace_roots: [ws],
})
assert(accEv.permission === 'allow', 8, 'accept allow evidence')

// --- Owner: allow specs ---
run('prompt.mjs', {
  prompt: '排期需求池拍板切片',
  conversation_id: 'own',
  workspace_roots: [ws],
})
const ownSpec = run('tool.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/docs/specs/v2026.07-demo/VERSION.md', contents: '1' },
  conversation_id: 'own',
  workspace_roots: [ws],
})
assert(ownSpec.permission === 'allow', 9, 'owner allow specs')

// --- Claude harness path (same entry + --harness=claude) ---
const claude = ['--harness=claude']
run(
  'prompt.mjs',
  { prompt: '优化X\n1、a', session_id: 'v', cwd: ws },
  claude
)
const hd = run(
  'tool.mjs',
  {
    tool_name: 'Edit',
    tool_input: { file_path: ws + '/src/x.ts', old_string: 'a', new_string: 'b' },
    session_id: 'v',
    cwd: ws,
  },
  claude
)
assert(hd?.hookSpecificOutput?.permissionDecision === 'deny', 4, 'harness deny')
const ha = run(
  'tool.mjs',
  {
    tool_name: 'Write',
    tool_input: { file_path: ws + '/docs/product/demand-pool.md', content: '1' },
    session_id: 'v',
    cwd: ws,
  },
  claude
)
assert(ha?.hookSpecificOutput?.permissionDecision === 'allow', 5, 'harness allow')

console.log('ok')
