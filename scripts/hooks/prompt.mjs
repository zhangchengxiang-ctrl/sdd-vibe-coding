#!/usr/bin/env node
/**
 * prompt — classify rail on submit (mirrors rules/00)
 * Cursor: beforeSubmitPrompt · Claude: UserPromptSubmit (--harness=claude)
 */
import {
  readStdin,
  parseHookInput,
  classifyPrompt,
  writeRail,
  out,
  resolveHarness,
  resolveWorkspaceRoots,
  claudeOut,
  debugLog,
} from './shared.mjs'

const harness = resolveHarness()
const raw = await readStdin()
const input = parseHookInput(raw)
const prompt = input.prompt || input.user_prompt || ''
const { rail, reason } = classifyPrompt(prompt)

const normalized =
  harness === 'claude'
    ? {
        ...input,
        workspace_roots: resolveWorkspaceRoots(input),
        conversation_id: input.session_id || input.conversation_id || 'default',
        session_id: input.session_id || input.conversation_id || 'default',
      }
    : input

writeRail(normalized, rail, reason)
debugLog('prompt', `harness=${harness}`, `rail=${rail}`, `reason=${reason}`)

if (harness === 'claude') {
  claudeOut({
    hookSpecificOutput: {
      hookEventName: 'UserPromptSubmit',
      additionalContext: `【SDD 判轨】当前轨=${rail}（${reason}）。Intake/Owner/Accept 禁止写业务代码；Accept 只测不改。（权威 rules/00）`,
    },
  })
} else {
  out({ continue: true })
}
