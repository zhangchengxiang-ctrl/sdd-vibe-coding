#!/usr/bin/env node
/**
 * SDD Superpowers — shared rail helpers + Cursor/Claude I/O adapters
 */
import fs from 'node:fs'
import path from 'node:path'

// ── stdin / JSON ──────────────────────────────────────────────

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

export function out(obj) {
  process.stdout.write(JSON.stringify(obj))
}

/** cursor | claude — from argv; default cursor */
export function resolveHarness(argv = process.argv) {
  if (argv.includes('--harness=claude') || argv.includes('--claude')) return 'claude'
  if (argv.includes('--harness=cursor') || argv.includes('--cursor')) return 'cursor'
  return 'cursor'
}

// ── rail state ────────────────────────────────────────────────

export function railStatePath(input) {
  const roots = input.workspace_roots || []
  const root = roots[0] || process.cwd()
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

/**
 * Classify user prompt → intake | owner | build | accept
 * Mirrors rules/00-judge-track-first.mdc — keep signals in sync with that file.
 */
export function classifyPrompt(prompt = '') {
  const t = String(prompt)
  if (
    /开始做|按这个来|帮我构建|构建一下|挂\s*Spec|修\s*remediation|执行\s+docs\/specs/i.test(t) ||
    /实现(?!上)/.test(t)
  ) {
    return { rail: 'build', reason: 'explicit-build-signal' }
  }
  if (
    /跑验收矩阵|强制进入\s*\*?\*?验收|\/accept\b|验收矩阵|走查|总评|只测不改|再测对话|回归验收|(^|[^\w])验收([^\w]|$)/i.test(
      t
    )
  ) {
    return { rail: 'accept', reason: 'accept-signal' }
  }
  if (/排期|优先|需求池|拍板切片|这周做什么|缓做|不做/.test(t)) {
    return { rail: 'owner', reason: 'owner-signal' }
  }
  if (/优化|改进|我希望|吐槽|坏了|应该|不要有|挪到|信息架构|导航|顶栏/.test(t)) {
    return { rail: 'intake', reason: 'wish-or-optimize' }
  }
  if (/^\s*\d+[.、．)]/m.test(t) || /编号清单|截图/.test(t)) {
    return { rail: 'intake', reason: 'numbered-list-wish' }
  }
  return { rail: 'intake', reason: 'default-intake' }
}

/**
 * Path allowlist for non-Build rails.
 * @param {'intake'|'owner'|'accept'|'build'} rail
 */
export function isAllowlistedWritePath(filePath, workspaceRoots = [], rail = 'intake') {
  const abs = path.resolve(filePath)
  const roots = (workspaceRoots.length ? workspaceRoots : [process.cwd()]).map((r) => path.resolve(r))
  const inWorkspace = roots.some((r) => abs === r || abs.startsWith(r + path.sep))
  if (!inWorkspace) return { ok: false, why: 'outside-workspace' }

  const rel = path.relative(roots.find((r) => abs === r || abs.startsWith(r + path.sep)), abs)
  const norm = rel.split(path.sep).join('/')

  const metaOk =
    norm === 'AGENTS.md' ||
    norm === 'CLAUDE.md' ||
    norm === 'README.md' ||
    norm === 'LICENSE' ||
    norm.startsWith('.cursor/') ||
    norm.startsWith('.claude/') ||
    norm.startsWith('.agents/') ||
    norm === '.gitignore'

  if (metaOk) return { ok: true, why: 'sdd-allowlist' }

  if (rail === 'intake') {
    if (norm === 'docs' || norm.startsWith('docs/product/') || norm === 'docs/product') {
      return { ok: true, why: 'intake-product' }
    }
    if (
      norm.startsWith('docs/reference/') ||
      norm.startsWith('docs/guides/') ||
      norm.startsWith('docs/planning/') ||
      norm === 'docs/README.md' ||
      norm === 'docs/README.zh-CN.md'
    ) {
      return { ok: true, why: 'intake-docs-meta' }
    }
    if (norm.startsWith('docs/specs/') || norm === 'docs/specs') {
      return { ok: false, why: 'intake-no-specs' }
    }
    if (norm.startsWith('docs/')) return { ok: false, why: 'intake-docs-narrow' }
    return { ok: false, why: 'business-path' }
  }

  if (rail === 'owner' || rail === 'accept') {
    if (norm === 'docs' || norm.startsWith('docs/')) {
      return { ok: true, why: 'sdd-allowlist' }
    }
    return { ok: false, why: 'business-path' }
  }

  if (norm === 'docs' || norm.startsWith('docs/product/')) {
    return { ok: true, why: 'sdd-allowlist' }
  }
  return { ok: false, why: 'business-path' }
}

export function looksLikeWriteShell(command = '') {
  const c = String(command)
  if (
    /^\s*(ls|find|cat|head|tail|rg|grep|wc|pwd|git status|git diff|git log|bash .+scaffold\.sh)\b/.test(
      c
    )
  ) {
    return false
  }
  if (/\b(scaffold\.sh)\b/.test(c) && !/\brm\s+-rf\b/.test(c)) return false
  if (
    /^\s*(make\s+(check|test|test-\S+|verify-\S+|status|help)|npm\s+(test|run\s+test\S*)|npx\s+vitest|node\s+scripts\/verify)\b/.test(
      c
    )
  ) {
    return false
  }
  if (
    /\b(npm|pnpm|yarn|pip|cargo|make|sed\s+-i|perl\s+-i|python3?\s+\S+\.py|node\s+\S+)\b/.test(c) ||
    /(^|[;&|]\s*)(rm|mv|cp|tee|install|chmod|chown|mkdir|touch)\b/.test(c) ||
    />|>>|tee\s/.test(c) ||
    /\bgit\s+(commit|add|push|checkout|reset|rebase|merge)\b/.test(c)
  ) {
    return true
  }
  return true
}

export function isWriteRestrictedRail(rail) {
  return rail !== 'build'
}

/**
 * Shared mutating-tool gate. Returns { allow: true } or { allow: false, message }.
 */
export function evaluateMutatingToolGate({ tool, toolInput = {}, roots = [], rail = 'intake' }) {
  const readOnly =
    /^(Read|Grep|Glob|SemanticSearch|AwaitShell|GetMcpTools|FetchMcpResource)$/i.test(tool)
  if (readOnly) return { allow: true }

  const isMutating = /^(Write|Delete|StrReplace|EditNotebook|Shell)$/i.test(tool)
  if (!isMutating) return { allow: true }

  const fp = toolInput.path || toolInput.target_notebook || toolInput.file_path || ''

  if (!isWriteRestrictedRail(rail)) {
    if (/^(Write|Delete|StrReplace|EditNotebook)$/i.test(tool) && fp && roots.length) {
      const abs = path.resolve(fp)
      const inWs = roots.some((r) => {
        const rr = path.resolve(r)
        return abs === rr || abs.startsWith(rr + path.sep)
      })
      if (!inWs) {
        return { allow: false, message: 'SDD 闸：禁止修改工作区外的文件。请只在当前 workspace 内改。' }
      }
    }
    return { allow: true }
  }

  if (/^(Write|Delete|StrReplace|EditNotebook)$/i.test(tool)) {
    if (!fp) return { allow: false, message: 'SDD 闸：缺少写入路径，已拒绝。' }
    const check = isAllowlistedWritePath(fp, roots, rail)
    if (!check.ok) {
      if (check.why === 'outside-workspace') {
        return { allow: false, message: `SDD 闸：禁止修改工作区外文件。当前轨=${rail}。` }
      }
      if (check.why === 'intake-no-specs') {
        return {
          allow: false,
          message:
            'SDD 闸：Intake 禁止新建/改 docs/specs/。请写 demand-pool / modules；升格 Spec 归 Owner。',
        }
      }
      return {
        allow: false,
        message: `SDD 闸：当前轨=${rail}。禁止写业务代码。Intake→docs/product；Owner/Accept→docs/**；明示「开始做」后进 Build。`,
      }
    }
    return { allow: true }
  }

  if (/^Shell$/i.test(tool)) {
    const cmd = toolInput.command || ''
    if (/\bscaffold\.sh\b/.test(cmd)) return { allow: true }
    if (looksLikeWriteShell(cmd)) {
      return {
        allow: false,
        message: `SDD 闸：当前轨=${rail}。禁止用 Shell 改业务代码。只读调查、verify、或跑 scaffold.sh。`,
      }
    }
    return { allow: true }
  }

  return { allow: true }
}

// ── Claude / Codex adapters ───────────────────────────────────

export function resolveWorkspaceRoots(input = {}) {
  const roots = []
  if (Array.isArray(input.workspace_roots)) roots.push(...input.workspace_roots)
  if (input.cwd) roots.push(input.cwd)
  if (process.env.CLAUDE_PROJECT_DIR) roots.push(process.env.CLAUDE_PROJECT_DIR)
  if (process.env.CODEX_PROJECT_DIR) roots.push(process.env.CODEX_PROJECT_DIR)
  if (!roots.length) roots.push(process.cwd())
  return [...new Set(roots.map((r) => path.resolve(r)))]
}

/** Map Claude/Codex tool names → Cursor-like names for gate logic */
export function normalizeTool(input = {}) {
  const raw = input.tool_name || input.toolName || ''
  const toolInput = input.tool_input || input.toolInput || input.input || {}
  let tool = raw
  const mapped = { ...toolInput }

  if (/^Edit$/i.test(raw)) {
    tool = 'StrReplace'
    if (mapped.file_path && !mapped.path) mapped.path = mapped.file_path
  } else if (/^Write$/i.test(raw)) {
    tool = 'Write'
    if (mapped.file_path && !mapped.path) mapped.path = mapped.file_path
  } else if (/^Bash$/i.test(raw)) {
    tool = 'Shell'
  } else if (/^NotebookEdit$/i.test(raw)) {
    tool = 'EditNotebook'
    if (mapped.notebook_path && !mapped.target_notebook) {
      mapped.target_notebook = mapped.notebook_path
    }
  }

  return {
    tool_name: tool,
    tool_input: mapped,
    conversation_id: input.session_id || input.conversation_id || 'default',
    session_id: input.session_id || input.conversation_id || 'default',
    workspace_roots: resolveWorkspaceRoots(input),
    prompt: input.prompt || input.user_prompt || '',
    raw_tool_name: raw,
  }
}

export function sddEnabled(roots = []) {
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

export function debugLog(tag, ...args) {
  if (process.env.SDD_HOOK_DEBUG !== '1') return
  try {
    fs.appendFileSync(
      '/tmp/sdd-hook.log',
      `[${tag} ${new Date().toISOString()}] ${args.join(' ')}\n`
    )
  } catch {
    /* ignore */
  }
}

export function claudeOut(obj) {
  process.stdout.write(JSON.stringify(obj))
}

export function claudeAllow() {
  claudeOut({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'allow',
    },
  })
}

export function claudeDeny(reason) {
  claudeOut({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason,
    },
  })
}

/** Shared SessionStart — keep short; body lives in rules/ + SYSTEM.md */
export function gateContextLines() {
  return [
    '【SDD】先判轨（默认 Intake；优化/清单≠开始做）→ rules/00。编码许可证=归属 Spec 或明示开始做（DEM≠放行）→ rules/01。Accept=只测禁热修。入口：vibe-coding · role-rails（Intake/Owner/Build/Accept）。地图：插件 SYSTEM.md §1。',
  ]
}
