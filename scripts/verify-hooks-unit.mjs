#!/usr/bin/env node
/**
 * Unit: Cursor + Claude harness Intake write gate
 */
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const ws = '/tmp/sdd-verify-ws'
fs.rmSync(ws, { recursive: true, force: true })
fs.mkdirSync(path.join(ws, '.cursor', 'rules'), { recursive: true })
fs.writeFileSync(path.join(ws, '.cursor', 'sdd-enabled'), '1')
fs.writeFileSync(path.join(ws, '.cursor', 'rules', '01-product-memory-first.mdc'), 'x')
fs.mkdirSync(path.join(ws, 'docs', 'product'), { recursive: true })

function run(script, input) {
  const r = spawnSync('node', [path.join(root, 'scripts/hooks', script)], {
    input: JSON.stringify(input),
    encoding: 'utf8',
  })
  if (r.status) {
    console.error(script, r.stderr || r.stdout)
    process.exit(1)
  }
  return JSON.parse(r.stdout || '{}')
}

run('before-submit-prompt.mjs', {
  prompt: '优化X\n1、a\n2、b',
  conversation_id: 'v',
  workspace_roots: [ws],
})
const d = run('pre-tool-use.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/src/x.ts', contents: '1' },
  conversation_id: 'v',
  workspace_roots: [ws],
})
if (d.permission !== 'deny') process.exit(2)
const a = run('pre-tool-use.mjs', {
  tool_name: 'Write',
  tool_input: { path: ws + '/docs/product/demand-pool.md', contents: '1' },
  conversation_id: 'v',
  workspace_roots: [ws],
})
if (a.permission !== 'allow') process.exit(3)

run('harness-user-prompt.mjs', { prompt: '优化X\n1、a', session_id: 'v', cwd: ws })
const hd = run('harness-pre-tool-use.mjs', {
  tool_name: 'Edit',
  tool_input: { file_path: ws + '/src/x.ts', old_string: 'a', new_string: 'b' },
  session_id: 'v',
  cwd: ws,
})
if (hd?.hookSpecificOutput?.permissionDecision !== 'deny') process.exit(4)
const ha = run('harness-pre-tool-use.mjs', {
  tool_name: 'Write',
  tool_input: { file_path: ws + '/docs/product/demand-pool.md', content: '1' },
  session_id: 'v',
  cwd: ws,
})
if (ha?.hookSpecificOutput?.permissionDecision !== 'allow') process.exit(5)
console.log('ok')
