#!/usr/bin/env node
/**
 * tool — mutating-tool write gate (mirrors rules/01)
 * Cursor: preToolUse · Claude: PreToolUse (--harness=claude)
 */
import {
  readStdin,
  parseHookInput,
  readRail,
  evaluateMutatingToolGate,
  out,
  resolveHarness,
  normalizeTool,
  sddEnabled,
  claudeAllow,
  claudeDeny,
  debugLog,
} from './shared.mjs'

const harness = resolveHarness()
const raw = await readStdin()
const input = parseHookInput(raw)

let tool, toolInput, roots, railInput
if (harness === 'claude') {
  const norm = normalizeTool(input)
  tool = norm.tool_name
  toolInput = norm.tool_input
  roots = norm.workspace_roots
  railInput = norm
  debugLog('tool', norm.raw_tool_name, '→', tool, 'path=', toolInput.path || toolInput.command || '')
} else {
  tool = input.tool_name || ''
  toolInput = input.tool_input || {}
  roots = input.workspace_roots || []
  railInput = input
  debugLog('tool', tool, 'path=', toolInput.path || toolInput.command || '')
}

function cursorDeny(agentMsg, userMsg) {
  debugLog('tool', 'DENY', agentMsg)
  out({
    permission: 'deny',
    agent_message: agentMsg,
    user_message: userMsg || agentMsg,
  })
}

function cursorAllow() {
  debugLog('tool', 'ALLOW')
  out({ permission: 'allow' })
}

if (!sddEnabled(roots)) {
  if (harness === 'claude') claudeAllow()
  else cursorAllow()
  process.exit(0)
}

const { rail } = readRail(railInput)
debugLog('tool', 'rail=', rail)

const result = evaluateMutatingToolGate({ tool, toolInput, roots, rail })
if (!result.allow) {
  if (harness === 'claude') claudeDeny(result.message)
  else cursorDeny(result.message, 'Blocked by SDD track gate')
  process.exit(0)
}

if (harness === 'claude') claudeAllow()
else cursorAllow()
