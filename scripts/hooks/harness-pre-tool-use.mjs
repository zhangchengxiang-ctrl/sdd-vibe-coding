#!/usr/bin/env node
/**
 * Claude Code / Codex PreToolUse adapter → shared SDD write gate
 */
import fs from 'node:fs'
import path from 'node:path'
import {
  readStdin,
  parseHookInput,
  readRail,
  isAllowlistedWritePath,
  looksLikeWriteShell,
} from './lib.mjs'
import {
  normalizeTool,
  sddEnabled,
  claudeAllow,
  claudeDeny,
} from './harness-lib.mjs'

const raw = await readStdin()
const input = parseHookInput(raw)
const norm = normalizeTool(input)
const { tool_name: tool, tool_input: toolInput, workspace_roots: roots } = norm

function log(...args) {
  try {
    fs.appendFileSync(
      '/tmp/sdd-hook.log',
      `[harness-preTool ${new Date().toISOString()}] ${args.join(' ')}\n`
    )
  } catch {
    /* ignore */
  }
}

log(norm.raw_tool_name, '→', tool, 'rail-pending', 'path=', toolInput.path || toolInput.command || '')

if (!sddEnabled(roots)) {
  claudeAllow()
  process.exit(0)
}

const { rail } = readRail(norm)
log('rail=', rail)

if (/^(Read|Grep|Glob)$/i.test(tool)) {
  claudeAllow()
  process.exit(0)
}

const isMutating = /^(Write|Delete|StrReplace|EditNotebook|Shell)$/i.test(tool)
if (!isMutating) {
  claudeAllow()
  process.exit(0)
}

if (rail === 'build') {
  if (/^(Write|Delete|StrReplace|EditNotebook)$/i.test(tool)) {
    const fp = toolInput.path || toolInput.target_notebook || toolInput.file_path || ''
    if (fp && roots.length) {
      const abs = path.resolve(fp)
      const inWs = roots.some((r) => {
        const rr = path.resolve(r)
        return abs === rr || abs.startsWith(rr + path.sep)
      })
      if (!inWs) {
        claudeDeny('SDD 闸：禁止修改工作区外的文件。请只在当前 workspace 内改。')
        process.exit(0)
      }
    }
  }
  claudeAllow()
  process.exit(0)
}

if (/^(Write|Delete|StrReplace|EditNotebook)$/i.test(tool)) {
  const fp = toolInput.path || toolInput.target_notebook || toolInput.file_path || ''
  if (!fp) {
    claudeDeny('SDD 闸：缺少写入路径，已拒绝。')
    process.exit(0)
  }
  const check = isAllowlistedWritePath(fp, roots)
  if (!check.ok) {
    const msg =
      check.why === 'outside-workspace'
        ? 'SDD 闸：禁止修改工作区外文件。当前轨=Intake/Owner。'
        : `SDD 闸：当前轨=${rail}（产品记忆先行）。禁止写业务代码。只允许 docs/**、AGENTS.md、.cursor/**、.claude/**。请写 demand-pool / modules；用户明示「开始做」后再编码。`
    claudeDeny(msg)
    process.exit(0)
  }
  claudeAllow()
  process.exit(0)
}

if (/^Shell$/i.test(tool)) {
  const cmd = toolInput.command || ''
  if (/\bscaffold\.sh\b/.test(cmd)) {
    claudeAllow()
    process.exit(0)
  }
  if (looksLikeWriteShell(cmd)) {
    claudeDeny(
      `SDD 闸：当前轨=${rail}。禁止用 Shell/Bash 改业务代码。只读调查或跑 scaffold.sh；请写入 docs/product/demand-pool.md。`
    )
    process.exit(0)
  }
  claudeAllow()
  process.exit(0)
}

claudeAllow()
