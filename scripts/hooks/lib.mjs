#!/usr/bin/env node
/**
 * SDD Superpowers — shared rail helpers for hooks
 */
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'

export function readStdin() {
  return new Promise((resolve, reject) => {
    let data = ''
    process.stdin.setEncoding('utf8')
    process.stdin.on('data', (c) => (data += c))
    process.stdin.on('end', () => resolve(data))
    process.stdin.on('error', reject)
  })
}

export function parseHookInput(raw) {
  try {
    return JSON.parse(raw || '{}')
  } catch {
    return {}
  }
}

export function railStatePath(input) {
  const roots = input.workspace_roots || []
  const root = roots[0] || process.cwd()
  // Prefer .cursor (Cursor scaffold); fall back to .claude for Claude-only hosts
  const cursorDir = path.join(root, '.cursor')
  const claudeDir = path.join(root, '.claude')
  const dir = fs.existsSync(cursorDir) || !fs.existsSync(claudeDir) ? cursorDir : claudeDir
  fs.mkdirSync(dir, { recursive: true })
  const sid = input.conversation_id || input.session_id || 'default'
  return path.join(dir, `sdd-rail-${sid}.json`)
}

export function writeRail(input, rail, reason) {
  const p = railStatePath(input)
  fs.writeFileSync(
    p,
    JSON.stringify(
      {
        rail,
        reason,
        updatedAt: new Date().toISOString(),
        conversation_id: input.conversation_id || input.session_id || null,
      },
      null,
      2
    )
  )
  return p
}

export function readRail(input) {
  const p = railStatePath(input)
  if (!fs.existsSync(p)) return { rail: 'intake', reason: 'default-intake' }
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'))
  } catch {
    return { rail: 'intake', reason: 'corrupt-default-intake' }
  }
}

/** Classify user prompt → intake | owner | build */
export function classifyPrompt(prompt = '') {
  const t = String(prompt)
  if (/开始做|实现|按这个来|帮我构建|构建一下|挂\s*Spec|修\s*remediation|跑验收矩阵|执行\s+docs\/specs/i.test(t)) {
    return { rail: 'build', reason: 'explicit-build-signal' }
  }
  if (/排期|优先|需求池|拍板切片|这周做什么|缓做|不做/.test(t)) {
    return { rail: 'owner', reason: 'owner-signal' }
  }
  // Fake Build signals + default wish language → Intake
  if (/优化|改进|我希望|吐槽|坏了|应该|不要有|挪到|信息架构|导航|顶栏/.test(t)) {
    return { rail: 'intake', reason: 'wish-or-optimize' }
  }
  if (/^\s*\d+[.、．)]/m.test(t) || /编号清单|截图/.test(t)) {
    return { rail: 'intake', reason: 'numbered-list-wish' }
  }
  return { rail: 'intake', reason: 'default-intake' }
}

export function isAllowlistedWritePath(filePath, workspaceRoots = []) {
  const abs = path.resolve(filePath)
  const roots = (workspaceRoots.length ? workspaceRoots : [process.cwd()]).map((r) => path.resolve(r))
  const inWorkspace = roots.some((r) => abs === r || abs.startsWith(r + path.sep))
  if (!inWorkspace) return { ok: false, why: 'outside-workspace' }

  const rel = path.relative(roots.find((r) => abs === r || abs.startsWith(r + path.sep)), abs)
  const norm = rel.split(path.sep).join('/')

  // Product memory + SDD docs + constitution + cursor meta
  if (
    norm === 'AGENTS.md' ||
    norm === 'CLAUDE.md' ||
    norm === 'README.md' ||
    norm === 'LICENSE' ||
    norm.startsWith('docs/') ||
    norm.startsWith('.cursor/') ||
    norm.startsWith('.claude/') ||
    norm.startsWith('.agents/') ||
    norm === '.gitignore' ||
    norm === 'docs'
  ) {
    return { ok: true, why: 'sdd-allowlist' }
  }
  return { ok: false, why: 'business-path' }
}

export function looksLikeWriteShell(command = '') {
  const c = String(command)
  // Allow read-only / scaffold
  if (/^\s*(ls|find|cat|head|tail|rg|grep|wc|pwd|git status|git diff|git log|bash .+scaffold\.sh)\b/.test(c)) {
    return false
  }
  if (/\b(scaffold\.sh)\b/.test(c) && !/\brm\s+-rf\b/.test(c)) return false
  // Dangerous / mutating
  if (
    /\b(npm|pnpm|yarn|pip|cargo|make|sed\s+-i|perl\s+-i|python3?\s+\S+\.py|node\s+\S+)\b/.test(c) ||
    /(^|[;&|]\s*)(rm|mv|cp|tee|install|chmod|chown|mkdir|touch)\b/.test(c) ||
    />|>>|tee\s/.test(c) ||
    /\bgit\s+(commit|add|push|checkout|reset|rebase|merge)\b/.test(c)
  ) {
    return true
  }
  return true // Intake: default deny unknown shell
}

export function out(obj) {
  process.stdout.write(JSON.stringify(obj))
}
