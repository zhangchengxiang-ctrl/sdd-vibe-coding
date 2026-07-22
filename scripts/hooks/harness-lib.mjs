#!/usr/bin/env node
/**
 * Normalize Claude Code / Codex hook stdin into Cursor-shaped input
 * used by shared gate helpers.
 */
import path from 'node:path'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'

export function pluginRootFromMeta(metaUrl) {
  // scripts/hooks → repo root
  return path.resolve(path.dirname(fileURLToPath(metaUrl)), '../..')
}

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
