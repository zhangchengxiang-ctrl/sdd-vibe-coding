#!/usr/bin/env node
import fs from 'node:fs'
import { readStdin, parseHookInput, classifyPrompt, writeRail } from './lib.mjs'
import { resolveWorkspaceRoots, sddEnabled, claudeOut } from './harness-lib.mjs'

const raw = await readStdin()
const input = parseHookInput(raw)
const roots = resolveWorkspaceRoots(input)

if (!sddEnabled(roots)) {
  claudeOut({})
  process.exit(0)
}

const prompt = input.prompt || input.user_prompt || ''
const { rail, reason } = classifyPrompt(prompt)
const normalized = {
  ...input,
  workspace_roots: roots,
  conversation_id: input.session_id || input.conversation_id || 'default',
  session_id: input.session_id || input.conversation_id || 'default',
}
writeRail(normalized, rail, reason)

try {
  fs.appendFileSync(
    '/tmp/sdd-hook.log',
    `[harness-user-prompt ${new Date().toISOString()}] rail=${rail} reason=${reason}\n`
  )
} catch {
  /* ignore */
}

claudeOut({
  hookSpecificOutput: {
    hookEventName: 'UserPromptSubmit',
    additionalContext: `【SDD 判轨】当前轨=${rail}（${reason}）。Intake/Owner 禁止写业务代码。`,
  },
})
