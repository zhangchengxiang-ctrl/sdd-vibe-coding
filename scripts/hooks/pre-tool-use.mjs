#!/usr/bin/env node
import path from 'node:path'
import fs from 'node:fs'
import {
  readStdin,
  parseHookInput,
  readRail,
  isAllowlistedWritePath,
  looksLikeWriteShell,
  out,
} from './lib.mjs'

function log(...args) {
  try {
    fs.appendFileSync(
      '/tmp/sdd-hook.log',
      `[preToolUse ${new Date().toISOString()}] ${args.join(' ')}\n`
    )
  } catch {
    /* ignore */
  }
}

const raw = await readStdin()
const input = parseHookInput(raw)
const tool = input.tool_name || ''
const toolInput = input.tool_input || {}
const roots = input.workspace_roots || []
const { rail } = readRail(input)
log(
  tool,
  'rail=',
  rail,
  'roots=',
  JSON.stringify(roots),
  'path=',
  toolInput.path || toolInput.command || ''
)

function deny(agentMsg, userMsg) {
  log('DENY', agentMsg)
  out({
    permission: 'deny',
    agent_message: agentMsg,
    user_message: userMsg || agentMsg,
  })
}

function allow() {
  log('ALLOW')
  out({ permission: 'allow' })
}

/** Only enforce when this workspace was scaffolded by SDD Superpowers */
function sddEnabled() {
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

if (!sddEnabled()) {
  allow()
  process.exit(0)
}

if (/^(Read|Grep|Glob|SemanticSearch|AwaitShell|GetMcpTools|FetchMcpResource)$/i.test(tool)) {
  allow()
  process.exit(0)
}

const isMutatingTool = /^(Write|Delete|StrReplace|EditNotebook|Shell)$/i.test(tool)
if (!isMutatingTool) {
  allow()
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
        deny(
          'SDD 闸：禁止修改工作区外的文件。请只在当前 workspace 内改。',
          'Blocked: write outside workspace'
        )
        process.exit(0)
      }
    }
  }
  allow()
  process.exit(0)
}

if (/^(Write|Delete|StrReplace|EditNotebook)$/i.test(tool)) {
  const fp = toolInput.path || toolInput.target_notebook || toolInput.file_path || ''
  if (!fp) {
    deny('SDD 闸：缺少写入路径，已拒绝。', 'Blocked: missing path')
    process.exit(0)
  }
  const check = isAllowlistedWritePath(fp, roots)
  if (!check.ok) {
    const msg =
      check.why === 'outside-workspace'
        ? 'SDD 闸：禁止修改工作区外文件。当前轨=Intake/Owner。'
        : `SDD 闸：当前轨=${rail}（产品记忆先行）。禁止写业务代码。只允许 docs/**、AGENTS.md、.cursor/**。请写 demand-pool / modules；用户明示「开始做」后再编码。`
    deny(msg, 'Blocked by SDD product-memory / track gate')
    process.exit(0)
  }
  allow()
  process.exit(0)
}

if (/^Shell$/i.test(tool)) {
  const cmd = toolInput.command || ''
  if (/\bscaffold\.sh\b/.test(cmd)) {
    allow()
    process.exit(0)
  }
  if (looksLikeWriteShell(cmd)) {
    deny(
      `SDD 闸：当前轨=${rail}。禁止用 Shell 改业务代码。只读调查或跑 scaffold.sh；请写入 docs/product/demand-pool.md。`,
      'Blocked by SDD Intake shell gate'
    )
    process.exit(0)
  }
  allow()
  process.exit(0)
}

allow()
