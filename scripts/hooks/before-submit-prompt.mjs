#!/usr/bin/env node
import path from 'node:path'
import fs from 'node:fs'
import { readStdin, parseHookInput, classifyPrompt, writeRail, out } from './lib.mjs'

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
  out({ continue: true })
  process.exit(0)
}

const prompt = input.prompt || ''
const { rail, reason } = classifyPrompt(prompt)
writeRail(input, rail, reason)
try {
  fs.appendFileSync(
    '/tmp/sdd-hook.log',
    `[beforeSubmit ${new Date().toISOString()}] rail=${rail} reason=${reason} prompt=${JSON.stringify(prompt).slice(0, 160)}\n`
  )
} catch {
  /* ignore */
}

out({ continue: true })
